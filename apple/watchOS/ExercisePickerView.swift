import SwiftUI

/// Adds an exercise to the workout in progress, grouped by primary muscle.
struct ExercisePickerView: View {
    @EnvironmentObject private var store: WatchStore
    let onPick: (String) -> Void

    var body: some View {
        let all = store.exercises.values.filter { !$0.primary.isEmpty }
        let muscles = Set(all.flatMap { $0.primary.prefix(1) }).sorted { store.library.muscleName($0) < store.library.muscleName($1) }
        NavigationStack {
            List(muscles, id: \.self) { m in
                NavigationLink(store.library.muscleName(m)) {
                    List(all.filter { $0.primary.first == m }.sorted { ($0.tier ?? 0, $1.name) > ($1.tier ?? 0, $0.name) }) { ex in
                        Button(ex.name) { onPick(ex.id) }
                    }
                    .navigationTitle(store.library.muscleName(m))
                }
            }
            .navigationTitle("Add exercise")
        }
    }
}
