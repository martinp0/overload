import SwiftUI

struct StartView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        List {
            Section {
                Button { start(name: "Workout", items: []) } label: {
                    Label("Empty workout", systemImage: "plus.circle.fill")
                }
            }
            if !store.context.templates.isEmpty {
                Section("Saved") {
                    ForEach(store.context.templates) { t in row(t) }
                }
            }
            if !store.context.recent.isEmpty {
                Section("Repeat") {
                    ForEach(store.context.recent) { t in row(t) }
                }
            }
            if store.context.templates.isEmpty && store.context.recent.isEmpty {
                Text("Saved workouts from the Overload iPhone app show up here.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Overload")
    }

    private func row(_ t: WorkoutTemplate) -> some View {
        Button { start(name: t.name, items: t.items) } label: {
            VStack(alignment: .leading) {
                Text(t.name).font(.headline)
                Text("\(t.items.count) exercises").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func start(name: String, items: [TemplateItem]) {
        store.begin(name: name, items: items)
        Task {
            if await workout.requestAuthorization() { await workout.start() }
        }
    }
}
