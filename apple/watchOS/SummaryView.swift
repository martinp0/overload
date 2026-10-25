import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var store: WatchStore
    @Environment(\.dismiss) private var dismiss
    let workout: Workout

    var body: some View {
        let st = Engine.stats(workout)
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Saved").font(.title3.bold()).foregroundStyle(.green)
                Text(workout.name).font(.headline)
                Text("\(workout.exercises.count) exercises · \(st.sets) sets")
                Text("Volume \(Int(store.unit.display(st.volume))) \(store.unit.rawValue)")
                if let kcal = workout.health?.activeKcal { Text("\(Int(kcal)) kcal") }
                if let hr = workout.health?.avgHeartRate { Text("Avg \(Int(hr)) bpm") }
                Text("Sent to your iPhone. It also appears in the Fitness app.")
                    .font(.caption2).foregroundStyle(.secondary)
                Button("Done") { dismiss() }
            }
        }
    }
}
