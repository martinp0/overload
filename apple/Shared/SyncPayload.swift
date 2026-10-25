import Foundation

/// What the iPhone sends to the Watch (as WatchConnectivity application context).
/// Kept small: templates, a few recent workouts to repeat, and "last time" sets for prefilling.
struct WatchContext: Codable, Sendable {
    var unit: WeightUnit
    var templates: [WorkoutTemplate]
    var recent: [WorkoutTemplate]
    var lastSets: [String: [SetEntry]]
    var custom: [Exercise]
    var updatedAt: EpochMS

    static let empty = WatchContext(unit: .kg, templates: [], recent: [], lastSets: [:], custom: [], updatedAt: 0)
}

enum SyncKey {
    static let context = "context"   // phone → watch, application context, JSON WatchContext
    static let workout = "workout"   // watch → phone, transferUserInfo, JSON Workout
}

enum JSONCoding {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    static let decoder = JSONDecoder()
}
