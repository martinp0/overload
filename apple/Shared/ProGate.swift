import Foundation

/// Free-tier limits for Overload Pro. Pure logic so it can be tested without StoreKit.
enum ProGate {
    static let monthlyID = "cz.martinpohl.overload.pro.monthly"
    static let yearlyID = "cz.martinpohl.overload.pro.yearly"
    static let lifetimeID = "cz.martinpohl.overload.pro.lifetime"
    static let productIDs = [monthlyID, yearlyID, lifetimeID]

    /// Saved workouts (templates) without Pro.
    static let freeTemplates = 3
    /// History visible without Pro, in months. Older workouts stay stored and exported.
    static let freeHistoryMonths = 3

    static func canSaveTemplate(existing: Int, isPro: Bool) -> Bool {
        isPro || existing < freeTemplates
    }

    static func historyCutoff(now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: -freeHistoryMonths, to: now) ?? now
    }

    /// Splits history into what's visible and how many older workouts are locked.
    static func visibleHistory<T>(_ items: [T], date: (T) -> Date, isPro: Bool, now: Date = Date(),
                                  calendar: Calendar = .current) -> (visible: [T], locked: Int) {
        if isPro { return (items, 0) }
        let cutoff = historyCutoff(now: now, calendar: calendar)
        let visible = items.filter { date($0) >= cutoff }
        return (visible, items.count - visible.count)
    }
}
