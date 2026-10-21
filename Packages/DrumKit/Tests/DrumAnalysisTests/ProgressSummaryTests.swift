import Foundation
import Testing
@testable import DrumAnalysis

private let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
private let now = Date(timeIntervalSince1970: 1_792_000_000)   // a Wednesday

private func rec(_ daysAgo: Double, bpm: Double = 70, andMs: Double = 0, minutes: Double = 10) -> SessionRecord {
    SessionRecord(date: now.addingTimeInterval(-daysAgo * 86_400), exerciseId: "A", title: "A", skill: "R", bpm: bpm,
                  minutes: minutes, stats: eighthStats(andMs: andMs), isLevelTest: false)
}

@Test func streakCountsConsecutiveDaysIncludingToday() {
    let p = ProgressSummary(records: [rec(0), rec(1), rec(2), rec(4)], now: now, calendar: cal)
    #expect(p.streakDays == 3)
}

@Test func missedDayResetsStreak() {
    #expect(ProgressSummary(records: [rec(1), rec(2)], now: now, calendar: cal).streakDays == 2)   // today not yet practised still counts yesterday's streak
    #expect(ProgressSummary(records: [rec(2), rec(3)], now: now, calendar: cal).streakDays == 0)
}

@Test func minutesThisWeek() {
    let p = ProgressSummary(records: [rec(0, minutes: 10), rec(1, minutes: 20), rec(10, minutes: 99)], now: now, calendar: cal)
    #expect(p.minutesThisWeek == 30)
}

@Test func bestCleanTempoIgnoresSloppyRuns() {
    let p = ProgressSummary(records: [rec(1, bpm: 80), rec(0, bpm: 95, andMs: 60)], now: now, calendar: cal)
    #expect(p.bestCleanTempo(exerciseId: "A", minScore: 90) == 80)
    #expect(p.bestCleanTempo(exerciseId: "B", minScore: 90) == nil)
}

@Test func weakestPosition() {
    let p = ProgressSummary(records: [rec(0, andMs: 28), rec(1, andMs: 32)], now: now, calendar: cal)
    #expect(p.weakestBeatPosition == "&")
    #expect(ProgressSummary(records: [], now: now, calendar: cal).weakestBeatPosition == nil)
}

@Test func cleanTempoSeries() {
    let p = ProgressSummary(records: [rec(3, bpm: 70), rec(2, bpm: 74), rec(1, bpm: 78)], now: now, calendar: cal)
    #expect(p.cleanTempoSeries(exerciseId: "A").map(\.bpm) == [70, 74, 78])
}

@Test func tempoChartListsPractisedExercisesMostMinutesFirst() {
    let rs = [
        SessionRecord(date: now, exerciseId: "B", title: "B", skill: "", bpm: 70, minutes: 5, stats: eighthStats(andMs: 0), isLevelTest: false),
        SessionRecord(date: now, exerciseId: "A", title: "A", skill: "", bpm: 70, minutes: 30, stats: eighthStats(andMs: 0), isLevelTest: false),
        SessionRecord(date: now, exerciseId: "T", title: "Test", skill: "", bpm: 75, minutes: 60, stats: eighthStats(andMs: 0), isLevelTest: true),
    ]
    let ids = ProgressSummary(records: rs, now: now, calendar: cal).exerciseIds.map(\.id)
    #expect(ids == ["A", "B"])          // level tests (fixed tempo) are left out
}
