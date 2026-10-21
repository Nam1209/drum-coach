import DrumCore
import Testing
@testable import DrumLibrary

private let l1 = LevelCatalog.levels[0]

@Test func ninetyIsNotEnough() {
    let t = l1.tests[0]
    #expect(!LevelProgress(bestScores: [t.id: 90.0]).isPassed(t))
    #expect(LevelProgress(bestScores: [t.id: 90.1]).isPassed(t))
}

@Test func levelNeedsEveryTest() {
    var scores: [String: Double] = [:]
    for t in l1.tests.dropLast() { scores[t.id] = 95 }
    #expect(!LevelProgress(bestScores: scores).isPassed(l1))
    scores[l1.tests.last!.id] = 91
    #expect(LevelProgress(bestScores: scores).isPassed(l1))
}

@Test func currentLevelIsContiguous() {
    var scores: [String: Double] = [:]
    for t in LevelCatalog.levels[0].tests + LevelCatalog.levels[2].tests { scores[t.id] = 100 }
    let p = LevelProgress(bestScores: scores)
    #expect(p.currentLevel == 1)
    #expect(p.isUnlocked(LevelCatalog.levels[1]))
    #expect(!p.isUnlocked(LevelCatalog.levels[3]))
}

@Test func firstTimeEverythingIsOpen() {
    let p = LevelProgress(bestScores: [:])
    #expect(p.currentLevel == 0)
    #expect(LevelCatalog.levels.allSatisfy { p.isUnlocked($0) })
}

@Test func catalogIsValid() throws {
    #expect(LevelCatalog.levels.map(\.id) == Array(1...8))
    #expect(LevelCatalog.passMark == 90)
    var ids = Set<String>()
    for level in LevelCatalog.levels {
        #expect((3...5).contains(level.tests.count), "level \(level.id)")
        for t in level.tests {
            #expect(ids.insert(t.id).inserted, "duplicate id \(t.id)")
            _ = try ExerciseDSL.parse(t.dsl)
        }
    }
}

@Test func difficultyNeverDrops() throws {
    let maxima = try LevelCatalog.levels.map { level in try level.tests.map { try LevelCatalog.difficulty($0) }.max()! }
    #expect(zip(maxima, maxima.dropFirst()).allSatisfy { $0 <= $1 })
}

@Test func levelsAlreadyReachedStayPassedWhenTestIdsChange() {
    // Grades 1–2 were passed on the default tests; a newly added book replaced their ids, so no scores match.
    let levels = (1...4).map { g in Level(id: g, title: "G\(g)", tests: [LevelTestItem(id: "book-\(g)", dsl: "", bpm: 70, skill: "")]) }
    let p = LevelProgress(bestScores: ["old-1": 95], levels: levels, reached: 2)
    #expect(p.currentLevel == 2)
    #expect(p.isPassed(levels[1]))
    #expect(p.isUnlocked(levels[2]) && !p.isUnlocked(levels[3]))
    #expect(LevelProgress(bestScores: ["book-3": 95, "book-1": 95, "book-2": 92], levels: levels, reached: 1).currentLevel == 3)
}
