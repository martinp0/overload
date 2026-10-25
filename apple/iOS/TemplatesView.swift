import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject private var store: OverloadStore
    @EnvironmentObject private var sync: PhoneSync

    var body: some View {
        NavigationStack {
            List {
                if !sync.watchAvailable {
                    Section {
                        Label("Install Overload on your Apple Watch to start these workouts from your wrist.", systemImage: "applewatch")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if store.templates.isEmpty {
                    Text("No saved workouts. Open a workout in History and tap Save, or import a backup from the web app.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.templates) { t in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.name).font(.headline)
                        Text(t.items.map { store.exerciseName($0.exId) }.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .onDelete { idx in for i in idx { store.deleteTemplate(id: store.templates[i].id) } }
            }
            .navigationTitle("Saved workouts")
        }
    }
}
