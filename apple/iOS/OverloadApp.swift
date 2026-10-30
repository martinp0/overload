import SwiftUI

@main
struct OverloadApp: App {
    @StateObject private var store = OverloadStore()
    @StateObject private var sync = PhoneSync()
    @StateObject private var pro = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(sync)
                .environmentObject(pro)
                .tint(.overloadAccent)
                .onAppear { sync.start(store: store) }
                .task { await pro.load() }
        }
    }
}

extension Color {
    /// Matches the web app's dark background (#1c1f24) and its --blue accent.
    static let overloadInk = Color(red: 0x1c / 255, green: 0x1f / 255, blue: 0x24 / 255)
    static let overloadAccent = Color(red: 0x25 / 255, green: 0x63 / 255, blue: 0xd8 / 255) // --blue in css/app.css
}

struct RootView: View {
    var body: some View {
        TabView {
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            TemplatesView()
                .tabItem { Label("Saved", systemImage: "bookmark") }
            DataView()
                .tabItem { Label("Data", systemImage: "arrow.up.arrow.down.circle") }
        }
    }
}
