import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: OverloadStore
    @EnvironmentObject private var pro: ProStore
    @State private var paywall = false

    var body: some View {
        let shown = ProGate.visibleHistory(store.history, date: { $0.startedAt.date }, isPro: pro.isPro)
        return NavigationStack {
            Group {
                if store.history.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Log a workout on your Apple Watch, or import a backup from the web app on the Data tab.")
                    )
                } else {
                    List {
                        ForEach(shown.visible) { w in
                            NavigationLink(value: w.id) { WorkoutRow(workout: w) }
                        }
                        .onDelete { idx in
                            for i in idx { store.deleteWorkout(id: shown.visible[i].id) }
                        }
                        if shown.locked > 0 {
                            Button { paywall = true } label: {
                                Label("\(shown.locked) older workouts – unlock with Overload Pro", systemImage: "lock")
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(isPresented: $paywall) { ProPaywallView() }
            .navigationDestination(for: String.self) { id in
                if let w = store.history.first(where: { $0.id == id }) { WorkoutDetailView(workout: w) }
            }
        }
    }
}

struct WorkoutRow: View {
    @EnvironmentObject private var store: OverloadStore
    let workout: Workout

    var body: some View {
        let st = Engine.stats(workout)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.name).font(.headline)
                if !(workout.records ?? []).isEmpty {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow).accessibilityLabel("New record")
                }
            }
            Text(workout.startedAt.date, format: .dateTime.weekday(.wide).day().month().hour().minute())
                .font(.subheadline).foregroundStyle(.secondary)
            Text("\(workout.exercises.count) exercises · \(st.sets) sets · \(Fmt.weight(st.volume, store.unit))")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject private var store: OverloadStore
    @EnvironmentObject private var pro: ProStore
    let workout: Workout
    @State private var templateName = ""
    @State private var askName = false
    @State private var paywall = false

    var body: some View {
        List {
            Section {
                LabeledContent("Started", value: workout.startedAt.date.formatted(date: .abbreviated, time: .shortened))
                if let d = Fmt.duration(workout) { LabeledContent("Duration", value: d) }
                if let h = workout.health {
                    if let kcal = h.activeKcal { LabeledContent("Active energy", value: "\(Int(kcal)) kcal") }
                    if let avg = h.avgHeartRate { LabeledContent("Avg heart rate", value: "\(Int(avg)) bpm") }
                    if let mx = h.maxHeartRate { LabeledContent("Max heart rate", value: "\(Int(mx)) bpm") }
                }
            }
            ForEach(workout.exercises) { e in
                let ex = store.exercises[e.exId]
                Section(store.exerciseName(e)) {
                    ForEach(Array(e.sets.enumerated()), id: \.offset) { i, s in
                        HStack {
                            Text(s.wu ? "W" : "\(i + 1)").foregroundStyle(.secondary).frame(width: 24)
                            Text(Fmt.set(s, ex, store.unit))
                            Spacer()
                            if (workout.records ?? []).contains(where: { $0.exId == e.exId }) && i == e.sets.count - 1 {
                                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.name)
        .toolbar {
            Button {
                if ProGate.canSaveTemplate(existing: store.templates.count, isPro: pro.isPro) {
                    templateName = workout.name; askName = true
                } else {
                    paywall = true
                }
            } label: { Label("Save as workout", systemImage: "bookmark") }
        }
        .sheet(isPresented: $paywall) { ProPaywallView() }
        .alert("Save workout", isPresented: $askName) {
            TextField("Name", text: $templateName)
            Button("Save") { store.saveTemplate(name: templateName.isEmpty ? workout.name : templateName, from: workout) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will appear on your Apple Watch so you can start it from your wrist.")
        }
    }
}
