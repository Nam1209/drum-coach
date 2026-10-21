import Foundation
import Testing
@testable import DrumAnalysis

@Test func goodRunsEarnPoints() {
    #expect(PracticePoints.points(score: 95, goodWindowMs: 30, isLevelTest: false) == 15)
    #expect(PracticePoints.points(score: 90, goodWindowMs: 30, isLevelTest: false) == 10)
    #expect(PracticePoints.points(score: 82, goodWindowMs: 30, isLevelTest: false) == 5)    // Merit band: +3…+8
    #expect(PracticePoints.points(score: 75, goodWindowMs: 30, isLevelTest: false) == 3)
    #expect(PracticePoints.points(score: 72, goodWindowMs: 30, isLevelTest: false) == 3)    // Pass band: +1…+3
    #expect(PracticePoints.points(score: 60, goodWindowMs: 30, isLevelTest: false) == 1)
}

@Test func learningZoneNeitherEarnsNorCosts() {
    #expect(PracticePoints.points(score: 59, goodWindowMs: 30, isLevelTest: false) == 0)
    #expect(PracticePoints.points(score: 40, goodWindowMs: 30, isLevelTest: false) == 0)
}

@Test func onlyVerySloppyRunsLosePointsAndOnlyAFew() {
    #expect(PracticePoints.points(score: 30, goodWindowMs: 30, isLevelTest: false) == -2)
    #expect(PracticePoints.points(score: 0, goodWindowMs: 30, isLevelTest: false) == -5)
}

@Test func runsStoppedWithinTenSecondsDoNotCount() {
    #expect(PracticePoints.points(score: 10, goodWindowMs: 30, isLevelTest: false, seconds: 8) == 0)
    #expect(PracticePoints.points(score: 98, goodWindowMs: 30, isLevelTest: false, seconds: 9.9) == 0)
    #expect(PracticePoints.points(score: 10, goodWindowMs: 30, isLevelTest: false, seconds: 10) == -4)
}

@Test func runsTheAppBarelyHeardDoNotCount() {
    // 17 of 17 notes missed: the mic heard nothing, which is not the player's fault.
    #expect(PracticePoints.points(score: 0, goodWindowMs: 30, isLevelTest: false, seconds: 60, missedFraction: 1) == 0)
    #expect(PracticePoints.points(score: 0, goodWindowMs: 30, isLevelTest: false, seconds: 60, missedFraction: 0.85) == -5)
}

@Test func difficultyScalesRewardsNotPenalties() {
    #expect(PracticePoints.points(score: 96, goodWindowMs: 20, isLevelTest: false) == 24)   // Khó ×1.5
    #expect(PracticePoints.points(score: 96, goodWindowMs: 45, isLevelTest: false) == 12)   // Dễ ×0.75
    #expect(PracticePoints.points(score: 20, goodWindowMs: 20, isLevelTest: false) == -3)
}

@Test func passingALevelTestEarnsBonus() {
    #expect(PracticePoints.points(score: 95, goodWindowMs: 30, isLevelTest: true) == 65)
    #expect(PracticePoints.points(score: 80, goodWindowMs: 30, isLevelTest: true) == 5)
}

@Test func totalNeverGoesBelowZero() {
    #expect(PracticePoints.total([10, -12, 5]) == 5)
    #expect(PracticePoints.total([]) == 0)
}

@Test(.vietnamese) func levelFollowsRockschoolGradeAndPractice() {
    // Nothing yet.
    let start = PracticeRank.for(points: 0, grade: 0)
    #expect(start.level == 0 && start.next == 10_000)
    // Grade 1 tests passed and enough practice: Level 1.
    let one = PracticeRank.for(points: 10_000, grade: 1)
    #expect(one.level == 1 && one.title == "Grade 1 · Giữ được nhịp" && one.floor == 10_000 && one.next == 20_000)
    #expect(!one.needsTest && !one.needsPractice)
    // Plenty of practice but no test passed: still Level 0, and told to take the test.
    let practised = PracticeRank.for(points: 25_000, grade: 0)
    #expect(practised.level == 0 && practised.needsTest)
    // Tests passed faster than the practice: level waits for the points.
    let quick = PracticeRank.for(points: 4_000, grade: 2)
    #expect(quick.level == 0 && quick.needsPractice && quick.next == 10_000)
    // Grades 6-8 take 1.5x the practice; Grade 8 is the top.
    #expect(PracticeRank.for(points: 65_000, grade: 6).level == 6)
    #expect(PracticeRank.for(points: 64_999, grade: 6).level == 5)
    #expect(PracticeRank.for(points: 200_000, grade: 8).next == nil)
}

@Test func finishingTheExerciseEarnsABonus() {
    #expect(PracticePoints.points(score: 60, goodWindowMs: 30, isLevelTest: false, seconds: 60, completed: true) == 1 + 2)  // Pass and finished
    #expect(PracticePoints.points(score: 59, goodWindowMs: 30, isLevelTest: false, seconds: 60, completed: true) == 0)      // finished, but under Pass
    #expect(PracticePoints.points(score: 95, goodWindowMs: 20, isLevelTest: false, seconds: 60, completed: true) == 23 + 2)  // bonus not multiplied
    #expect(PracticePoints.points(score: 0, goodWindowMs: 30, isLevelTest: false, seconds: 60, completed: true) == -5)      // under 40%: no bonus
    #expect(PracticePoints.points(score: 39, goodWindowMs: 30, isLevelTest: false, seconds: 60, completed: true) == -1)
    #expect(PracticePoints.points(score: 40, goodWindowMs: 30, isLevelTest: false, seconds: 60, completed: true) == 0)
    // Not for runs that don't count.
    #expect(PracticePoints.points(score: 95, goodWindowMs: 30, isLevelTest: false, seconds: 8, completed: true) == 0)
    #expect(PracticePoints.points(score: 0, goodWindowMs: 30, isLevelTest: false, seconds: 60, missedFraction: 1, completed: true) == 0)
}

@Test func longerExercisesEarnABiggerFinishingBonus() {
    #expect(PracticePoints.completionBonus(seconds: 20) == 2)      // short: the minimum
    #expect(PracticePoints.completionBonus(seconds: 60) == 2)
    #expect(PracticePoints.completionBonus(seconds: 120) == 4)
    #expect(PracticePoints.completionBonus(seconds: 300) == 10)
    #expect(PracticePoints.completionBonus(seconds: 1200) == 10)   // capped
    #expect(PracticePoints.points(score: 65, goodWindowMs: 30, isLevelTest: false, seconds: 180, completed: true) == 2 + 6)
}

@Test func weeklyDigestCarriesTheLevel() throws {
    let rank = PracticeRank.for(points: 25_000, grade: 1)
    let status = LevelStatus(rank: rank, points: 25_000)
    #expect(status.level == 1 && status.pointsToNext == 0 && status.nextAction == "takeTest")
    let d = HistorySummarizer.digest([], journal: [], level: status, currentLevel: 1, now: Date(timeIntervalSince1970: 1_800_000_000), calendar: .current)
    let json = String(data: try JSONEncoder().encode(d), encoding: .utf8)!
    #expect(json.contains("\"level\"") && json.contains("takeTest"))
    let behind = LevelStatus(rank: PracticeRank.for(points: 4_000, grade: 2), points: 4_000)
    #expect(behind.nextAction == "practise" && behind.pointsToNext == 6_000)
}
