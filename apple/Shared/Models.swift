import Foundation

// Native mirror of the web app's data model (js/store.js, js/engine.js).
// The JSON shape is identical to Settings → Export backup, so a file exported here can be
// imported in the browser and vice versa. Weights are always kilograms; times are Unix ms.

/// Milliseconds since 1970, as `Date.now()` produces in the web app.
typealias EpochMS = Int64

extension EpochMS {
    static var now: EpochMS { EpochMS(Date().timeIntervalSince1970 * 1000) }
    var date: Date { Date(timeIntervalSince1970: TimeInterval(self) / 1000) }
}

/// One set. `w` kg, `r` reps, `s` seconds, `wu` warm-up. Matches `{ w, r, s, wu }` in history.
struct SetEntry: Codable, Hashable, Sendable {
    var w: Double?
    var r: Double?
    var s: Double?
    var wu: Bool

    init(w: Double? = nil, r: Double? = nil, s: Double? = nil, wu: Bool = false) {
        self.w = w; self.r = r; self.s = s; self.wu = wu
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        w = try c.decodeIfPresent(Double.self, forKey: .w)
        r = try c.decodeIfPresent(Double.self, forKey: .r)
        s = try c.decodeIfPresent(Double.self, forKey: .s)
        wu = try c.decodeIfPresent(Bool.self, forKey: .wu) ?? false
    }

    func encode(to encoder: Encoder) throws {
        // The web app writes explicit nulls, so do the same.
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(w, forKey: .w)
        try c.encode(r, forKey: .r)
        try c.encode(s, forKey: .s)
        try c.encode(wu, forKey: .wu)
    }

    private enum CodingKeys: String, CodingKey { case w, r, s, wu }
}

struct WorkoutExercise: Codable, Hashable, Sendable, Identifiable {
    var exId: String
    var name: String?
    var min: Int?
    var max: Int?
    var rest: Int?
    var sets: [SetEntry]

    var id: String { exId }
    var workingSets: [SetEntry] { sets.filter { !$0.wu } }
}

struct PersonalRecord: Codable, Hashable, Sendable {
    var exId: String
    var type: String // weight | e1rm | time | reps
    var value: Double
}

/// A finished workout, exactly as stored in `overload.history`.
struct Workout: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var split: String?
    var startedAt: EpochMS
    var finishedAt: EpochMS?
    var exercises: [WorkoutExercise]
    var records: [PersonalRecord]?
    /// Native-only extra: energy and heart rate from the Watch session. The web app ignores unknown keys.
    var health: HealthSummary?
}

struct HealthSummary: Codable, Hashable, Sendable {
    var activeKcal: Double?
    var avgHeartRate: Double?
    var maxHeartRate: Double?
}

struct TemplateItem: Codable, Hashable, Sendable {
    var exId: String
    var sets: Int
    var min: Int
    var max: Int
    var rest: Int
}

struct WorkoutTemplate: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var createdAt: EpochMS?
    var items: [TemplateItem]
}

/// Built-in or custom exercise. `track`: wr | bw | r | t | wt (see js/data.js TRACKS).
struct Exercise: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var primary: [String]
    var secondary: [String]
    var equipment: [String]
    var kind: String
    var track: String
    var tier: Int?

    var isTimed: Bool { track == "t" || track == "wt" }
    var hasWeight: Bool { track == "wr" || track == "bw" || track == "wt" }
    var logsReps: Bool { track == "wr" || track == "bw" || track == "r" }
}

/// The whole backup file (`exportData()` in js/store.js).
struct OverloadBackup: Codable, Sendable {
    var app: String = "overload"
    var version: Int = 1
    var exportedAt: String?
    var settings: JSONValue?
    var history: [Workout]
    var templates: [WorkoutTemplate]?
    var custom: [Exercise]?
    var prefs: JSONValue?

    static let empty = OverloadBackup(history: [])

    /// Display unit chosen in the web app's settings ("kg" or "lb").
    var unit: WeightUnit { WeightUnit(rawValue: settings?["unit"]?.stringValue ?? "kg") ?? .kg }
}

enum WeightUnit: String, Codable, Sendable {
    case kg, lb
    static let lbPerKg = 2.20462262185

    func display(_ kg: Double) -> Double { self == .lb ? kg * Self.lbPerKg : kg }
    func toKg(_ v: Double) -> Double { self == .lb ? v / Self.lbPerKg : v }
    /// Default step for the Digital Crown / steppers, in the display unit.
    var step: Double { self == .lb ? 5 : 2.5 }
}

enum ID {
    /// Same format as `uid()` in js/store.js: base36 time + 6 random base36 chars.
    static func make() -> String {
        let t = String(EpochMS.now, radix: 36)
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        let rand = String((0..<6).map { _ in alphabet.randomElement()! })
        return t + rand
    }
}
