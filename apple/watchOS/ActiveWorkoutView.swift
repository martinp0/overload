import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var workout: WorkoutManager
    let onFinish: (Workout) -> Void
    @State private var confirmEnd = false
    @State private var picking = false

    var body: some View {
        if let a = store.active {
            List {
                Section {
                    MetricsHeader(startedAt: a.startedAt.date)
                }
                Section {
                    ForEach(a.entries) { e in
                        NavigationLink(value: e.uid) {
                            VStack(alignment: .leading) {
                                Text(e.name).font(.headline).lineLimit(2)
                                Text(e.isComplete ? "Done" : "\(e.doneCount)/\(e.sets.count) sets")
                                    .font(.caption2).foregroundStyle(e.isComplete ? .green : .secondary)
                            }
                        }
                    }
                    Button { picking = true } label: { Label("Add exercise", systemImage: "plus") }
                }
                Section {
                    Button { confirmEnd = true } label: { Label("Finish", systemImage: "flag.checkered") }
                        .foregroundStyle(.tint)
                }
            }
            .navigationTitle(a.name)
            .navigationDestination(for: String.self) { uid in SetLoggerView(entryUID: uid) }
            .sheet(isPresented: $picking) { ExercisePickerView { store.addExercise($0); picking = false } }
            .confirmationDialog("Finish workout?", isPresented: $confirmEnd) {
                Button("Save") { Task { await finish(save: true) } }
                Button("Discard", role: .destructive) { Task { await finish(save: false) } }
                Button("Keep going", role: .cancel) {}
            }
        }
    }

    private func finish(save: Bool) async {
        let logged = store.active?.entries.contains { $0.doneCount > 0 } ?? false
        let health = await workout.end(save: save && logged)
        if save, let w = store.finish(health: health) { onFinish(w) } else { store.discard() }
    }
}

struct MetricsHeader: View {
    @EnvironmentObject private var workout: WorkoutManager
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { ctx in
            VStack(alignment: .leading, spacing: 2) {
                Text(Duration.seconds(ctx.date.timeIntervalSince(startedAt)), format: .time(pattern: .hourMinuteSecond))
                    .font(.system(.title3, design: .rounded).monospacedDigit()).foregroundStyle(.yellow)
                HStack {
                    Label(workout.heartRate > 0 ? "\(Int(workout.heartRate))" : "--", systemImage: "heart.fill")
                        .foregroundStyle(.red)
                    Spacer()
                    Text("\(Int(workout.activeKcal)) kcal").foregroundStyle(.secondary)
                }
                .font(.system(.body, design: .rounded).monospacedDigit())
            }
        }
    }
}
