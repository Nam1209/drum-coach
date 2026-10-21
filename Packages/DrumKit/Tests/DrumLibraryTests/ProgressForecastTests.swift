import Testing
@testable import DrumLibrary

private func learner(minutes: Double = 60, grade: Int = 2, passed: Int = 0, of total: Int = 5,
                     history: [ProgressForecast.PastGrade] = [], score: Double? = nil,
                     bpm: Double? = nil, bpmPerWeek: Double? = nil) -> ProgressForecast {
    ProgressForecast(minutesPerDay: minutes, currentGrade: grade, testsPassed: passed, testsInNextGrade: total,
                     pastGrades: history, recentAverageScore: score, currentBpm: bpm, bpmPerWeek: bpmPerWeek)
}

@Test func startsFromTestsAlreadyPassed() {
    #expect(abs(learner(passed: 2).position(afterMonths: 0) - 2.4) < 1e-9)
}

@Test func typicalPaceAtAnHourADay() {
    // 3.5 months per grade at 60 min/day for Grades up to 5.
    #expect(abs(learner().position(afterMonths: 3.5) - 3.0) < 1e-6)
}

@Test func fasterLearnersAreForecastFaster() {
    // Grade 2 took 1.75 months at an hour a day: twice the usual speed.
    let f = learner(history: [.init(grade: 2, months: 1.75, minutesPerDay: 60)])
    #expect(abs(f.paceFactor - 0.5) < 1e-9)
    #expect(abs(f.position(afterMonths: 3.5) - 4.0) < 1e-6)
}

@Test func paceFactorIsClamped() {
    #expect(learner(history: [.init(grade: 2, months: 40, minutesPerDay: 60)]).paceFactor == 2)
    #expect(learner(history: [.init(grade: 2, months: 0.1, minutesPerDay: 60)]).paceFactor == 0.5)
    #expect(learner().paceFactor == 1)
}

@Test func sloppyPracticeSlowsProgress() {
    #expect(learner(score: 50).qualityFactor == 1.5)
    #expect(learner(score: 70).qualityFactor == 1.2)
    #expect(learner(score: 85).qualityFactor == 1.0)
    #expect(learner(score: 95).qualityFactor == 0.9)
    #expect(learner(score: 50).position(afterMonths: 6) < learner(score: 95).position(afterMonths: 6))
}

@Test func higherGradesTakeLongerAndStopAtEight() {
    #expect(abs(learner(grade: 5).position(afterMonths: 3.5) - (5 + 1 / 1.5)) < 1e-6)
    #expect(learner(grade: 7).position(afterMonths: 120) == 8)
}

@Test func tempoFollowsMeasuredTrendWithDiminishingGains() {
    let f = learner(bpm: 72, bpmPerWeek: 2)
    let one = f.bpm(afterMonths: 1)!, six = f.bpm(afterMonths: 6)!
    #expect(one > 72 && six > one)
    #expect(six - 72 < Int(2 * 26))          // slower than a straight line
    #expect(f.bpm(afterMonths: 60)! <= 72 + 60)
    #expect(learner(bpm: 72).bpm(afterMonths: 3) == nil)
}

@Test func moreMinutesShiftTheForecast() {
    let f = learner(minutes: 30, history: [.init(grade: 2, months: 4, minutesPerDay: 30)], bpm: 72, bpmPerWeek: 1)
    let more = f.with(minutesPerDay: 120)
    #expect(more.paceFactor == f.paceFactor)
    #expect(more.position(afterMonths: 6) > f.position(afterMonths: 6))
    #expect(more.bpm(afterMonths: 6)! > f.bpm(afterMonths: 6)!)
}
