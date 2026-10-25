import Foundation
import Combine

/// Local data store. Holds the same data as the web app's localStorage, persisted as one JSON
/// file in the app's Documents folder (visible in the Files app on iPhone).
@MainActor
final class OverloadStore: ObservableObject {
    @Published private(set) var data: OverloadBackup = .empty

    let library = ExerciseLibrary.builtIn
    private let fileURL: URL

    init(fileName: String = "overload-backup.json") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent(fileName)
        load()
    }

    var history: [Workout] { data.history }
    var templates: [WorkoutTemplate] { data.templates ?? [] }
    var unit: WeightUnit { data.unit }
    var exercises: [String: Exercise] { library.merged(with: data.custom ?? []) }

    func exerciseName(_ e: WorkoutExercise) -> String { exercises[e.exId]?.name ?? e.name ?? "Deleted exercise" }
    func exerciseName(_ id: String) -> String { exercises[id]?.name ?? "Deleted exercise" }

    // MARK: Persistence

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONCoding.decoder.decode(OverloadBackup.self, from: raw) {
            data = decoded
            sortHistory()
        }
    }

    private func persist() {
        do {
            let raw = try JSONCoding.encoder.encode(data)
            try raw.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("Overload: saving failed: \(error.localizedDescription)")
        }
        onChange?()
    }

    /// Called after every change (used to push fresh context to the Watch).
    var onChange: (() -> Void)?

    private func sortHistory() { data.history.sort { $0.startedAt > $1.startedAt } }

    // MARK: Import / export (compatible with Settings → Export/Import backup in the web app)

    enum ImportError: LocalizedError {
        case notOverload
        var errorDescription: String? { "That file isn't an Overload backup." }
    }

    nonisolated static func decodeBackup(_ raw: Data) throws -> OverloadBackup {
        let backup = try JSONCoding.decoder.decode(OverloadBackup.self, from: raw)
        guard backup.app == "overload" else { throw ImportError.notOverload }
        return backup
    }

    /// Replaces everything, exactly like the web app's import.
    func replaceAll(with backup: OverloadBackup) {
        data = backup
        sortHistory()
        persist()
    }

    /// Adds workouts/templates/custom exercises from a backup that aren't here yet (matched by id).
    /// Returns the number of workouts added.
    @discardableResult
    func merge(_ backup: OverloadBackup) -> Int {
        let known = Set(data.history.map(\.id))
        let newWorkouts = backup.history.filter { !known.contains($0.id) }
        data.history += newWorkouts
        let knownT = Set(templates.map(\.id))
        data.templates = templates + (backup.templates ?? []).filter { !knownT.contains($0.id) }
        let knownC = Set((data.custom ?? []).map(\.id))
        data.custom = (data.custom ?? []) + (backup.custom ?? []).filter { !knownC.contains($0.id) }
        if data.settings == nil { data.settings = backup.settings }
        if data.prefs == nil { data.prefs = backup.prefs }
        sortHistory()
        persist()
        return newWorkouts.count
    }

    func exportBackup() -> OverloadBackup {
        var b = data
        b.app = "overload"
        b.version = 1
        b.exportedAt = ISO8601DateFormatter.withFractions.string(from: Date())
        return b
    }

    // MARK: Editing

    /// Adds a workout logged on the Watch. Records are recomputed against the full history here.
    func addWorkout(_ incoming: Workout) {
        guard !data.history.contains(where: { $0.id == incoming.id }) else { return }
        var w = incoming
        w.records = Engine.detectRecords(w, history: data.history, exercises: exercises)
        data.history.append(w)
        sortHistory()
        persist()
    }

    func deleteWorkout(id: String) {
        data.history.removeAll { $0.id == id }
        persist()
    }

    func saveTemplate(name: String, from workout: Workout) {
        let tpl = WorkoutTemplate(id: ID.make(), name: name, createdAt: .now, items: Engine.templateItems(from: workout))
        data.templates = [tpl] + templates
        persist()
    }

    func deleteTemplate(id: String) {
        data.templates = templates.filter { $0.id != id }
        persist()
    }

    // MARK: Watch context

    func watchContext() -> WatchContext {
        let recent = history.prefix(5).map {
            WorkoutTemplate(id: "recent-\($0.id)", name: $0.name, createdAt: $0.startedAt, items: Engine.templateItems(from: $0))
        }
        var ids = Set<String>()
        for t in templates + recent { for i in t.items { ids.insert(i.exId) } }
        var last: [String: [SetEntry]] = [:]
        for id in ids { last[id] = Engine.lastSets(id, in: history) }
        return WatchContext(unit: unit, templates: templates, recent: Array(recent), lastSets: last,
                            custom: data.custom ?? [], updatedAt: .now)
    }
}

extension ISO8601DateFormatter {
    static let withFractions: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
