import Foundation

/// The built-in exercise library, generated from js/data.js by apple/scripts/export-exercises.mjs.
struct ExerciseLibrary: Sendable {
    let exercises: [Exercise]
    let muscles: [String: String]

    static let builtIn: ExerciseLibrary = {
        struct File: Decodable { let muscles: [String: String]; let exercises: [Exercise] }
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else { return ExerciseLibrary(exercises: [], muscles: [:]) }
        return ExerciseLibrary(exercises: file.exercises, muscles: file.muscles)
    }()

    /// Built-ins plus the user's custom exercises (custom ones win on id clash, like the web app).
    func merged(with custom: [Exercise]) -> [String: Exercise] {
        var map = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for c in custom { map[c.id] = c }
        return map
    }

    func muscleName(_ id: String) -> String { muscles[id] ?? id.replacingOccurrences(of: "_", with: " ").capitalized }
}
