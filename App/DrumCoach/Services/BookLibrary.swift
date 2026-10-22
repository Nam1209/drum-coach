import DrumLibrary
import Foundation

/// Rockschool grade data transcribed from the user's own books: bundled from PrivateLibrary/ at build time
/// (git-ignored) plus any files the user drops into Documents/PrivateLibrary.
enum BookLibrary {
    static func load() -> [GradeSyllabus] {
        var all: [Int: GradeSyllabus] = [:]
        let dirs = [Bundle.main.url(forResource: "PrivateLibrary", withExtension: nil),
                    URL.documentsDirectory.appending(path: "PrivateLibrary")].compactMap { $0 }
        for dir in dirs { for g in (try? PrivateLibraryLoader.load(from: dir)) ?? [] { all[g.grade] = g } }
        return all.values.sorted { $0.grade < $1.grade }
    }

    static var levels: [Level] { LevelCatalog.levels(with: load()) }
}
