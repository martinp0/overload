import SwiftUI
import WatchKit

/// Logs the sets of one exercise. The Digital Crown adjusts the selected field (weight, reps or
/// seconds); tick a set to save it and start the rest timer, like the web logger.
struct SetLoggerView: View {
    @EnvironmentObject private var store: WatchStore
    let entryUID: String

    @State private var setIndex = 0
    @State private var field: Field = .reps
    @State private var crown = 0.0
    @FocusState private var crownFocused: Bool

    enum Field { case weight, reps, seconds }

    private var entryIndex: Int? { store.active?.entries.firstIndex { $0.uid == entryUID } }

    var body: some View {
        if let ei = entryIndex, let entry = store.active?.entries[ei] {
            let ex = store.exercise(entry.exId)
            let set = entry.sets[min(setIndex, entry.sets.count - 1)]
            ScrollView {
                VStack(spacing: 6) {
                    HStack {
                        Text(set.wu ? "Warm-up" : "Set \(setIndex + 1) of \(entry.sets.count)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if set.done { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    }
                    HStack(spacing: 6) {
                        if ex.hasWeight {
                            valueButton(.weight, label: store.unit.rawValue, value: set.w.map { fmt(store.unit.display($0)) } ?? (ex.track == "bw" ? "BW" : "–"))
                        }
                        if ex.logsReps {
                            valueButton(.reps, label: "reps", value: set.r.map { "\(Int($0))" } ?? "–")
                        }
                        if ex.isTimed {
                            valueButton(.seconds, label: "sec", value: set.s.map { "\(Int($0))" } ?? "–")
                        }
                    }
                    Button { toggleDone(ei) } label: {
                        Label(set.done ? "Undo" : "Done", systemImage: set.done ? "arrow.uturn.backward" : "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(set.done ? .gray : .green)
                    HStack {
                        Button { move(-1, count: entry.sets.count) } label: { Image(systemName: "chevron.left") }
                            .disabled(setIndex == 0)
                        Button { addSet(ei) } label: { Image(systemName: "plus") }
                        Button { move(1, count: entry.sets.count) } label: { Image(systemName: "chevron.right") }
                            .disabled(setIndex >= entry.sets.count - 1)
                    }
                    Text("Target \(entry.min)–\(entry.max) \(ex.isTimed ? "sec" : "reps")")
                        .font(.caption2).foregroundStyle(.secondary)
                    RestTimerView()
                }
            }
            .navigationTitle(entry.name)
            .focusable()
            .focused($crownFocused)
            .digitalCrownRotation($crown, from: 0, through: 2000, by: step(ex), sensitivity: .medium,
                                  isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crown) { _, v in apply(v, ei) }
            .onAppear {
                setIndex = entry.sets.firstIndex { !$0.done } ?? 0
                field = ex.logsReps ? .reps : ex.isTimed ? .seconds : .weight
                syncCrown()
                crownFocused = true
            }
        }
    }

    private func valueButton(_ f: Field, label: String, value: String) -> some View {
        Button { field = f; syncCrown(); crownFocused = true } label: {
            VStack(spacing: 0) {
                Text(value).font(.system(.title3, design: .rounded).monospacedDigit()).minimumScaleFactor(0.6)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(field == f ? .accentColor : .gray)
    }

    private func fmt(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(0...2))) }

    private func step(_ ex: Exercise) -> Double {
        switch field {
        case .weight: return store.unit.step
        case .reps: return 1
        case .seconds: return 5
        }
    }

    private func currentSet() -> ActiveSet? {
        guard let ei = entryIndex, let e = store.active?.entries[ei], !e.sets.isEmpty else { return nil }
        return e.sets[min(setIndex, e.sets.count - 1)]
    }

    private func syncCrown() {
        guard let s = currentSet() else { return }
        switch field {
        case .weight: crown = store.unit.display(s.w ?? 0)
        case .reps: crown = s.r ?? 0
        case .seconds: crown = s.s ?? 0
        }
    }

    private func apply(_ v: Double, _ ei: Int) {
        guard var a = store.active, setIndex < a.entries[ei].sets.count else { return }
        switch field {
        case .weight: a.entries[ei].sets[setIndex].w = store.unit.toKg(max(0, v))
        case .reps: a.entries[ei].sets[setIndex].r = max(0, v.rounded())
        case .seconds: a.entries[ei].sets[setIndex].s = max(0, v.rounded())
        }
        store.active = a
    }

    private func toggleDone(_ ei: Int) {
        guard var a = store.active else { return }
        let wasDone = a.entries[ei].sets[setIndex].done
        a.entries[ei].sets[setIndex].done.toggle()
        if !wasDone {
            if a.entries[ei].sets[setIndex].w == nil && store.exercise(a.entries[ei].exId).track == "bw" {
                a.entries[ei].sets[setIndex].w = 0
            }
            a.restEndsAt = Date().addingTimeInterval(TimeInterval(a.entries[ei].rest))
            WKInterfaceDevice.current().play(.success)
        }
        store.active = a
        if !wasDone, let next = a.entries[ei].sets.firstIndex(where: { !$0.done }) {
            setIndex = next
            syncCrown()
        }
    }

    private func addSet(_ ei: Int) {
        guard var a = store.active else { return }
        var copy = a.entries[ei].sets.last ?? ActiveSet()
        copy.done = false
        copy.wu = false
        a.entries[ei].sets.append(copy)
        store.active = a
        setIndex = a.entries[ei].sets.count - 1
        syncCrown()
    }

    private func move(_ d: Int, count: Int) {
        setIndex = max(0, min(count - 1, setIndex + d))
        syncCrown()
    }
}

/// Counts down the rest after a ticked set and taps the wrist when it's over.
struct RestTimerView: View {
    @EnvironmentObject private var store: WatchStore
    @State private var alerted: Date?

    var body: some View {
        if let end = store.active?.restEndsAt, end > Date().addingTimeInterval(-3) {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let left = Int(end.timeIntervalSince(ctx.date).rounded(.up))
                HStack {
                    Image(systemName: "timer")
                    Text(left > 0 ? "Rest \(left / 60):\(String(format: "%02d", left % 60))" : "Rest over")
                        .monospacedDigit()
                    Spacer()
                    Button("Skip") { store.active?.restEndsAt = nil }.font(.caption2)
                }
                .foregroundStyle(left > 0 ? .primary : Color.green)
                .onChange(of: left <= 0) { _, over in
                    if over && alerted != end {
                        alerted = end
                        WKInterfaceDevice.current().play(.notification)
                    }
                }
            }
        }
    }
}
