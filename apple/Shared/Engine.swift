import Foundation

/// Ports of the bits of js/engine.js the native apps need.
enum Engine {
    /// Epley estimate, same as `e1rm()` in js/engine.js.
    static func e1rm(_ w: Double?, _ r: Double?) -> Double {
        guard let w, let r, w > 0, r > 0 else { return 0 }
        return r == 1 ? w : w * (1 + r / 30)
    }

    struct Bests { var e1 = 0.0, w = 0.0, r = 0.0, s = 0.0, n = 0 }

    static func bests(_ exId: String, before: EpochMS, in history: [Workout]) -> Bests {
        var out = Bests()
        for w in history where w.startedAt < before {
            for e in w.exercises where e.exId == exId {
                out.n += 1
                for s in e.workingSets {
                    out.e1 = max(out.e1, e1rm(s.w, s.r))
                    out.w = max(out.w, s.w ?? 0)
                    out.r = max(out.r, s.r ?? 0)
                    out.s = max(out.s, s.s ?? 0)
                }
            }
        }
        return out
    }

    /// Same rules as `detectRecords()` in js/engine.js.
    static func detectRecords(_ workout: Workout, history: [Workout], exercises: [String: Exercise]) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        let eps = 1e-6
        for e in workout.exercises {
            let prev = bests(e.exId, before: workout.startedAt, in: history)
            guard prev.n > 0 else { continue }
            let ex = exercises[e.exId] ?? Exercise(id: e.exId, name: e.name ?? e.exId, primary: [], secondary: [], equipment: [], kind: "i", track: "wr")
            let sets = e.workingSets
            func best(_ f: (SetEntry) -> Double) -> Double { max(0, sets.map(f).max() ?? 0) }
            let curW = best { $0.w ?? 0 }, curE1 = best { e1rm($0.w, $0.r) }
            let curR = best { $0.r ?? 0 }, curS = best { $0.s ?? 0 }
            if ex.hasWeight && curW > prev.w + eps { records.append(.init(exId: e.exId, type: "weight", value: curW)) }
            else if ex.track == "wr" && curE1 > prev.e1 + eps { records.append(.init(exId: e.exId, type: "e1rm", value: curE1)) }
            else if ex.isTimed && curS > prev.s { records.append(.init(exId: e.exId, type: "time", value: curS)) }
            else if (ex.track == "r" || ex.track == "bw") && curR > prev.r { records.append(.init(exId: e.exId, type: "reps", value: curR)) }
        }
        return records
    }

    static func stats(_ w: Workout) -> (sets: Int, volume: Double) {
        var sets = 0, volume = 0.0
        for e in w.exercises {
            for s in e.workingSets {
                sets += 1
                if let kg = s.w, let r = s.r, kg > 0, r > 0 { volume += kg * r }
            }
        }
        return (sets, volume)
    }

    /// Most recent working sets for an exercise, used to prefill the logger ("last time").
    static func lastSets(_ exId: String, in history: [Workout]) -> [SetEntry] {
        for w in history.sorted(by: { $0.startedAt > $1.startedAt }) {
            if let e = w.exercises.first(where: { $0.exId == exId }), !e.workingSets.isEmpty { return e.workingSets }
        }
        return []
    }

    /// Turns a finished workout into a template, like `itemFromEntry()`.
    static func templateItems(from w: Workout) -> [TemplateItem] {
        w.exercises.map { e in
            TemplateItem(exId: e.exId, sets: max(1, e.workingSets.count), min: e.min ?? 8, max: e.max ?? 12, rest: e.rest ?? 90)
        }
    }
}
