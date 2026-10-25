import Foundation
import WatchConnectivity

/// Watch-side state: the context pushed from the iPhone, the workout in progress (saved after
/// every change so a crash or reboot doesn't lose sets), and a short list of recently finished
/// workouts. Finished workouts go to the iPhone with `transferUserInfo`, which queues and retries
/// on its own when the phone is out of reach.
@MainActor
final class WatchStore: NSObject, ObservableObject {
    @Published private(set) var context: WatchContext = .empty
    @Published var active: ActiveWorkout? { didSet { saveActive() } }
    @Published private(set) var finished: [Workout] = []

    let library = ExerciseLibrary.builtIn
    private let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var contextURL: URL { docs.appendingPathComponent("context.json") }
    private var activeURL: URL { docs.appendingPathComponent("active.json") }
    private var finishedURL: URL { docs.appendingPathComponent("finished.json") }

    override init() {
        super.init()
        context = Self.read(WatchContext.self, contextURL) ?? .empty
        active = Self.read(ActiveWorkout.self, activeURL)
        finished = Self.read([Workout].self, finishedURL) ?? []
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    var unit: WeightUnit { context.unit }
    var exercises: [String: Exercise] { library.merged(with: context.custom) }

    func exercise(_ id: String) -> Exercise {
        exercises[id] ?? Exercise(id: id, name: "Exercise", primary: [], secondary: [], equipment: [], kind: "i", track: "wr")
    }

    // MARK: Workout lifecycle

    func begin(name: String, items: [TemplateItem]) {
        active = ActiveWorkout(name: name, items: items, store: self)
    }

    func addExercise(_ id: String) {
        guard var a = active else { return }
        let item = TemplateItem(exId: id, sets: 3, min: 8, max: 12, rest: 90)
        a.entries.append(ActiveEntry(item: item, name: exercise(id).name, last: context.lastSets[id] ?? []))
        active = a
    }

    /// Converts the active workout into a history record (same shape as `finishWorkout()` in
    /// js/engine.js) and sends it to the iPhone. Returns nil if nothing was logged.
    func finish(health: HealthSummary?) -> Workout? {
        guard let a = active else { return nil }
        active = nil
        let exercises = a.entries.compactMap { e -> WorkoutExercise? in
            let sets = e.sets.filter(\.done).map { SetEntry(w: $0.w, r: $0.r, s: $0.s, wu: $0.wu) }
            return sets.isEmpty ? nil : WorkoutExercise(exId: e.exId, name: e.name, min: e.min, max: e.max, rest: e.rest, sets: sets)
        }
        guard !exercises.isEmpty else { return nil }
        // Records are recomputed on the iPhone against the full history.
        let w = Workout(id: a.id, name: a.name, split: nil, startedAt: a.startedAt, finishedAt: .now,
                        exercises: exercises, records: [], health: health)
        finished = Array(([w] + finished).prefix(10))
        Self.write(finished, finishedURL)
        send(w)
        return w
    }

    func discard() { active = nil }

    private func send(_ w: Workout) {
        guard WCSession.isSupported(), let raw = try? JSONCoding.encoder.encode(w) else { return }
        WCSession.default.transferUserInfo([SyncKey.workout: raw])
    }

    // MARK: Files

    private func saveActive() {
        if let active { Self.write(active, activeURL) } else { try? FileManager.default.removeItem(at: activeURL) }
    }

    fileprivate func apply(contextData raw: Data) {
        guard let ctx = try? JSONCoding.decoder.decode(WatchContext.self, from: raw) else { return }
        context = ctx
        Self.write(ctx, contextURL)
    }

    private static func read<T: Decodable>(_ type: T.Type, _ url: URL) -> T? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONCoding.decoder.decode(T.self, from: raw)
    }

    private static func write<T: Encodable>(_ value: T, _ url: URL) {
        try? JSONCoding.encoder.encode(value).write(to: url, options: .atomic)
    }
}

extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let raw = session.receivedApplicationContext[SyncKey.context] as? Data
        if let raw { Task { @MainActor in self.apply(contextData: raw) } }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let raw = applicationContext[SyncKey.context] as? Data else { return }
        Task { @MainActor in self.apply(contextData: raw) }
    }
}

// MARK: - Workout in progress (mirrors `state.active` in the web app)

struct ActiveSet: Codable, Hashable {
    var w: Double?
    var r: Double?
    var s: Double?
    var wu = false
    var done = false
}

struct ActiveEntry: Codable, Hashable, Identifiable {
    var uid = ID.make()
    var exId: String
    var name: String
    var min: Int
    var max: Int
    var rest: Int
    var sets: [ActiveSet]

    var id: String { uid }
    var doneCount: Int { sets.filter(\.done).count }
    var isComplete: Bool { !sets.isEmpty && sets.allSatisfy(\.done) }

    /// Prefills each set with what was lifted last time, like the web logger's placeholders.
    init(item: TemplateItem, name: String, last: [SetEntry]) {
        exId = item.exId
        self.name = name
        min = item.min; max = item.max; rest = item.rest
        sets = (0..<Swift.max(1, item.sets)).map { i in
            let prev = last.isEmpty ? nil : last[Swift.min(i, last.count - 1)]
            return ActiveSet(w: prev?.w, r: prev?.r ?? Double(item.max), s: prev?.s ?? Double(item.max))
        }
    }
}

struct ActiveWorkout: Codable, Hashable {
    var id = ID.make()
    var name: String
    var startedAt: EpochMS = .now
    var entries: [ActiveEntry]
    var restEndsAt: Date?

    @MainActor
    init(name: String, items: [TemplateItem], store: WatchStore) {
        self.name = name
        entries = items.map { ActiveEntry(item: $0, name: store.exercise($0.exId).name, last: store.context.lastSets[$0.exId] ?? []) }
    }
}
