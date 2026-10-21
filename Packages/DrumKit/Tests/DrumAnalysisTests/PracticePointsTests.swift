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

@Test(.vietnamese) func ranksByTotal() {
    #expect(PracticeRank.for(points: 0).level == 1)
    #expect(PracticeRank.for(points: 99).level == 1)
    let r = PracticeRank.for(points: 100)
    #expect(r.level == 2 && r.title == "Giữ được nhịp")
    #expect(r.floor == 100 && r.next == 250)
    #expect(PracticeRank.for(points: 99_999).next == nil)
}

@Test func finishingTheExerciseEarnsABonus() {
    #expect(PracticePoints.points(score: 50, goodWindowMs: 30, isLevelTest: false, seconds: 60, completed: true) == 2)     // learning zone, but finished
    #expect(PracticePoints.points(score: 95, goodWindowMs: 20, isLevelTest: false, seconds: 60, completed: true) == 23 + 2)  // bonus not multiplied
    #expect(PracticePoints.points(score: 0, goodWindowMs: 30, isLevelTest: false, seconds: 60, completed: true) == -5)      // under 40%: no bonus
    #expect(PracticePoints.points(score: 39, goodWindowMs: 30, isLevelTest: false, seconds: 60, completed: true) == -1)
    #expect(PracticePoints.points(score: 40, goodWindowMs: 30, isLevelTest: false, seconds: 60, completed: true) == 2)
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
    #expect(PracticePoints.points(score: 50, goodWindowMs: 30, isLevelTest: false, seconds: 180, completed: true) == 6)
}
