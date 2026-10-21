import DrumCore
import Foundation
import Testing
@testable import DrumLibrary

private func tempDir() -> URL {
    let d = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

@Test func emptyPrivateLibrary() throws {
    #expect(try PrivateLibraryLoader.load(from: tempDir()).isEmpty)
    #expect(try PrivateLibraryLoader.load(from: URL(fileURLWithPath: "/nonexistent/dir")).isEmpty)
}

@Test func loadsBookGrade() throws {
    let dir = tempDir()
    let g = GradeSyllabus(grade: 1, techGroups: [LevelTestItem(id: "G1-A", dsl: "title: A\ntime: 4/4\ngrid: 2\nSN: xxxxxxxx\nST: RLRLRLRL", bpm: 70, skill: "Singles")],
                          fills: [], sightReadingBpm: 80, source: "book")
    try JSONEncoder().encode(g).write(to: dir.appending(path: "grade-1.json"))
    try Data("not json".utf8).write(to: dir.appending(path: "grade-2.json"))
    let loaded = try PrivateLibraryLoader.load(from: dir)
    #expect(loaded.map(\.grade) == [1])
    #expect(loaded[0].techGroups[0].bpm == 70)
}

@Test func invalidDSLInBookIsDropped() throws {
    let dir = tempDir()
    let g = GradeSyllabus(grade: 3, techGroups: [LevelTestItem(id: "bad", dsl: "garbage", bpm: 75, skill: "x")], fills: [], sightReadingBpm: 80, source: "book")
    try JSONEncoder().encode(g).write(to: dir.appending(path: "grade-3.json"))
    #expect(try PrivateLibraryLoader.load(from: dir).first?.techGroups.isEmpty == true)
}

@Test func missingGrades() {
    #expect(PrivateLibraryLoader.missingGrades(available: [1, 2, 3, 4], current: 4) == [5])
    #expect(PrivateLibraryLoader.missingGrades(available: [1, 2, 3, 4, 5], current: 5) == [6, 7, 8])
    #expect(PrivateLibraryLoader.missingGrades(available: [1, 2, 3, 4], current: 1) == [])
    #expect(PrivateLibraryLoader.missingGrades(available: Array(1...8), current: 8) == [])
}

@Test func bookTestsReplaceDefaultLevel() {
    let g = GradeSyllabus(grade: 1, techGroups: [LevelTestItem(id: "G1-A", dsl: "title: A\ntime: 4/4\ngrid: 2\nSN: xxxxxxxx\nST: RLRLRLRL", bpm: 70, skill: "S")],
                          fills: [], sightReadingBpm: 80, source: "book")
    let levels = LevelCatalog.levels(with: [g])
    #expect(levels[0].tests.map(\.id) == ["G1-A"])
    #expect(levels[1].tests == LevelCatalog.levels[1].tests)
}

@Test func bundledBookFilesParse() throws {
    // The user's own transcriptions (git-ignored); skipped when absent.
    let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../../../PrivateLibrary").standardized
    for g in try PrivateLibraryLoader.load(from: dir) {
        #expect(!g.techGroups.isEmpty, "grade \(g.grade) has no usable exercises")
    }
}
