import AppIntents

/// "How did my last workout go?" from Shortcuts, Spotlight, the Action button or Siri.
/// Reads the same local JSON as the app; nothing leaves the phone.
struct LastWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Workout"
    static var description = IntentDescription("Tells you your most recent workout: name, when, duration, working sets and new records.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let store = OverloadStore()
        guard let w = store.history.first else {
            return .result(value: "", dialog: "No workouts yet.")
        }
        let sets = w.exercises.reduce(0) { $0 + $1.workingSets.count }
        let when = w.startedAt.date.formatted(.relative(presentation: .named))
        var parts = ["\(w.name), \(when)", "\(w.exercises.count) exercises, \(sets) working sets"]
        if let d = Fmt.duration(w) { parts.append(d) }
        if let prs = w.records, !prs.isEmpty { parts.append("\(prs.count) new record\(prs.count == 1 ? "" : "s")") }
        let text = parts.joined(separator: ", ") + "."
        return .result(value: text, dialog: "\(text)")
    }
}

/// Training volume for the last 7 days, handy for a weekly Shortcuts automation.
struct WeekSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Week's Training"
    static var description = IntentDescription("Counts workouts and working sets in the last 7 days.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let store = OverloadStore()
        let since = EpochMS(Date().addingTimeInterval(-7 * 86_400).timeIntervalSince1970 * 1000)
        let week = store.history.filter { $0.startedAt >= since }
        let sets = week.reduce(0) { acc, w in acc + w.exercises.reduce(0) { $0 + $1.workingSets.count } }
        let text = week.isEmpty
            ? "No workouts in the last 7 days."
            : "\(week.count) workout\(week.count == 1 ? "" : "s") and \(sets) working sets in the last 7 days."
        return .result(value: week.count, dialog: "\(text)")
    }
}

struct OverloadShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LastWorkoutIntent(),
            phrases: [
                "Last workout in \(.applicationName)",
                "How was my last \(.applicationName) workout",
            ],
            shortTitle: "Last Workout",
            systemImageName: "dumbbell.fill"
        )
        AppShortcut(
            intent: WeekSummaryIntent(),
            phrases: [
                "My week in \(.applicationName)",
                "\(.applicationName) weekly summary",
            ],
            shortTitle: "This Week",
            systemImageName: "calendar"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .blue
}
