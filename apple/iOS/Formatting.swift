import Foundation

enum Fmt {
    static func weight(_ kg: Double?, _ unit: WeightUnit) -> String {
        guard let kg else { return "–" }
        let v = unit.display(kg)
        let rounded = (v * 100).rounded() / 100
        return rounded.formatted(.number.precision(.fractionLength(0...2))) + " " + unit.rawValue
    }

    static func set(_ s: SetEntry, _ ex: Exercise?, _ unit: WeightUnit) -> String {
        let track = ex?.track ?? "wr"
        let reps = s.r.map { "\(Int($0))" } ?? "–"
        let secs = s.s.map { "\(Int($0)) s" } ?? "–"
        switch track {
        case "r": return "\(reps) reps"
        case "t": return secs
        case "wt": return "\(weight(s.w, unit)) × \(secs)"
        case "bw": return (s.w ?? 0) > 0 ? "BW+\(weight(s.w, unit)) × \(reps)" : "BW × \(reps)"
        default: return "\(weight(s.w, unit)) × \(reps)"
        }
    }

    static func duration(_ w: Workout) -> String? {
        guard let end = w.finishedAt else { return nil }
        let mins = Int((end - w.startedAt) / 60_000)
        return mins >= 60 ? "\(mins / 60) h \(mins % 60) min" : "\(mins) min"
    }
}
