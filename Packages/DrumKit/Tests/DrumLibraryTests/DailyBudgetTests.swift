import Testing
@testable import DrumLibrary

@Test func shortDaysAreOneSession() {
    for m in [30, 60] {
        let p = DailyBudget.plan(minutes: m)
        #expect(p.sessions.count == 1)
        #expect(p.sessions[0].reduce(0) { $0 + $1.minutes } == m)
    }
}

@Test func longDaysAreSplitWithBreaks() {
    let two = DailyBudget.plan(minutes: 120)
    #expect(two.sessions.count == 2)
    #expect(two.practiceMinutes + two.breakMinutes * (two.sessions.count - 1) == 120)
    let four = DailyBudget.plan(minutes: 240)
    #expect(four.sessions.count == 4)
    #expect(four.sessions.allSatisfy { $0.reduce(0) { $0 + $1.minutes } <= 50 })
    #expect(four.practiceMinutes + four.breakMinutes * 3 == 240)
    #expect(!four.warnings.isEmpty)
    #expect(four.restDaysPerWeek >= 1)
}

@Test func otherAmountsUseTheNearestPlan() {
    #expect(DailyBudget.plan(minutes: 45).minutes == 30)
    #expect(DailyBudget.plan(minutes: 100).minutes == 120)
    #expect(DailyBudget.plan(minutes: 600).minutes == 240)
}

@Test func moreTimeGetsThereSoonerWithDiminishingReturns() {
    let m30 = DailyBudget.plan(minutes: 30).monthsToGrade(8, from: 2)
    let m60 = DailyBudget.plan(minutes: 60).monthsToGrade(8, from: 2)
    let m240 = DailyBudget.plan(minutes: 240).monthsToGrade(8, from: 2)
    #expect(m60 == 23...30)
    #expect(m30.lowerBound > m60.upperBound)
    #expect(m240.upperBound < m60.lowerBound)
    #expect(Double(m240.lowerBound) > Double(m60.lowerBound) / 4)      // 4× the time is not 4× faster
    #expect(DailyBudget.plan(minutes: 60).monthsToGrade(2, from: 2) == 0...0)
}
