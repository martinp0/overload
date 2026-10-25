import SwiftUI

@main
struct OverloadWatchApp: App {
    @StateObject private var store = WatchStore()
    @StateObject private var workout = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(workout)
                .tint(Color(red: 0x25 / 255, green: 0x63 / 255, blue: 0xd8 / 255))
                .task { if store.active != nil { await workout.recover() } }
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var store: WatchStore
    @State private var summary: Workout?

    var body: some View {
        NavigationStack {
            if store.active != nil {
                ActiveWorkoutView(onFinish: { summary = $0 })
            } else {
                StartView()
            }
        }
        .sheet(item: $summary) { SummaryView(workout: $0) }
    }
}
