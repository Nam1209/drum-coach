import DrumCore
import Foundation

/// A Rockschool grade's tests transcribed from the user's own book (kept in PrivateLibrary, never committed).
public struct GradeSyllabus: Codable, Sendable, Equatable {
    public let grade: Int
    public var techGroups: [LevelTestItem]
    public var fills: [LevelTestItem]
    public let sightReadingBpm: Int
    /// "book" | "generated"
    public let source: String

    public init(grade: Int, techGroups: [LevelTestItem], fills: [LevelTestItem], sightReadingBpm: Int, source: String) {
        self.grade = grade
        self.techGroups = techGroups
        self.fills = fills
        self.sightReadingBpm = sightReadingBpm
        self.source = source
    }
}

public enum PrivateLibraryLoader {
    /// Reads `grade-N.json` files; unreadable files are skipped and exercises whose DSL does not parse are dropped.
    public static func load(from dir: URL) throws -> [GradeSyllabus] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.lastPathComponent.hasPrefix("grade-") && $0.pathExtension == "json" }
            .compactMap { url -> GradeSyllabus? in
                guard let data = try? Data(contentsOf: url), var g = try? JSONDecoder().decode(GradeSyllabus.self, from: data),
                      (1...8).contains(g.grade) else { return nil }
                let valid: (LevelTestItem) -> Bool = { (try? ExerciseDSL.parse($0.dsl)) != nil && (30...300).contains($0.bpm) }
                g.techGroups = g.techGroups.filter(valid)
                g.fills = g.fills.filter(valid)
                return g
            }
            .sorted { $0.grade < $1.grade }
    }

    /// Books to ask for: the next grade's book, or — from Grade 5 on — every missing book up to Grade 8.
    public static func missingGrades(available: [Int], current: Int) -> [Int] {
        let have = Set(available)
        guard current < 8 else { return [] }
        let wanted = current >= 5 ? Array((current + 1)...8) : current >= 4 ? [current + 1] : []
        return wanted.filter { $0 <= 8 && !have.contains($0) }
    }
}

extension LevelCatalog {
    /// Default levels with every grade that has book data replaced by the book's technical exercises.
    public static func levels(with books: [GradeSyllabus]) -> [Level] {
        levels.map { level in
            guard let book = books.first(where: { $0.grade == level.id }), !book.techGroups.isEmpty else { return level }
            return Level(id: level.id, title: "Level \(level.id) · Rockschool Grade \(level.id) (sách của bạn)", tests: book.techGroups + book.fills)
        }
    }
}
