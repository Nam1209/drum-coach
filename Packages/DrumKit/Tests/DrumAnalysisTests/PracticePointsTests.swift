import Testing
@testable import DrumAnalysis

@Test func goodRunsEarnPoints() {
    #expect(PracticePoints.points(score: 95, goodWindowMs: 30, isLevelTest: false) == 15)
    #expect(PracticePoints.points(score: 90, goodWindowMs: 30, isLevelTest: false) == 10)
    #expect(PracticePoints.points(score: 72, goodWindowMs: 30, isLevelTest: false) == 2)
}

@Test func badRunsLosePoints() {
    #expect(PracticePoints.points(score: 50, goodWindowMs: 30, isLevelTest: false) == -2)
    #expect(PracticePoints.points(score: 0, goodWindowMs: 30, isLevelTest: false) == -12)
}

@Test func difficultyScalesRewardsNotPenalties() {
    #expect(PracticePoints.points(score: 96, goodWindowMs: 20, isLevelTest: false) == 24)   // Khó ×1.5
    #expect(PracticePoints.points(score: 96, goodWindowMs: 45, isLevelTest: false) == 12)   // Dễ ×0.75
    #expect(PracticePoints.points(score: 50, goodWindowMs: 20, isLevelTest: false) == -2)
}

@Test func passingALevelTestEarnsBonus() {
    #expect(PracticePoints.points(score: 95, goodWindowMs: 30, isLevelTest: true) == 65)
    #expect(PracticePoints.points(score: 80, goodWindowMs: 30, isLevelTest: true) == 3)
}

@Test func totalNeverGoesBelowZero() {
    #expect(PracticePoints.total([10, -12, 5]) == 5)
    #expect(PracticePoints.total([]) == 0)
}

@Test(.vietnamese) func ranksByTotal() {
    #expect(PracticeRank.for(points: 0).level == 1)
    #expect(PracticeRank.for(points: 99).level == 1)
    let r = PracticeRank.for(points: 100)
    #expect(r.level == 2 && r.title == "Giữ được nhịp")
    #expect(r.floor == 100 && r.next == 250)
    #expect(PracticeRank.for(points: 99_999).next == nil)
}
