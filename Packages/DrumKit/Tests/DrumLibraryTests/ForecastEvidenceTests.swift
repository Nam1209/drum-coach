import DrumAnalysis
import DrumCore
import Foundation
import Testing
@testable import DrumLibrary

private let now = Date(timeIntervalSince1970: 1_792_000_000)
private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

/// Stats whose score is `percent` (10 notes, the rest missed).
private func stats(_ percent: Int) -> SessionStats {
    let notes = (0..<10).map { TimedNote(index: $0, noteIndex: $0, repeatIndex: 0, note: NoteEvent(position: Rational($0, 2), voice: .snare), time: Double($0)) }
    var results: [Int: NoteResult] = [:]
    for i in 0..<10 { results[i] = i < percent / 10 ? .hit(offset: 0, velocity: 0.8) : .missed }
    return SessionStats(results: results, notes: notes, extraHits: 0)
}

private func rec(_ daysAgo: Double, minutes: Double = 30, score: Int = 80, bpm: Double = 70, id: String = "para", test: Bool = false) -> SessionRecord {
    SessionRecord(date: now.addingTimeInterval(-daysAgo * 86_400), exerciseId: id, title: id == "para" ? "Paradiddle" : id,
                  skill: "", bpm: bpm, minutes: minutes, stats: stats(score), isLevelTest: test)
}

private func level(_ id: Int, tests: Int) -> Level {
    Level(id: id, title: "G\(id)", tests: (0..<tests).map { LevelTestItem(id: "g\(id)-\($0)", dsl: "", bpm: 70, duration: 30, skill: "") })
}

private func evidence(_ records: [SessionRecord], reached: [(Int, Date)] = [], best: [String: Double] = [:], window: Int = 7) -> ForecastEvidence {
    ForecastEvidence(records: records, levelReached: reached, progress: LevelProgress(bestScores: best, levels: [level(1, tests: 2), level(2, tests: 5)]),
                     levels: [level(1, tests: 2), level(2, tests: 5)], windowDays: window, now: now, calendar: cal)
}

@Test func averagesMinutesOverTheWholeWindowIncludingDaysOff() {
    let e = evidence([rec(0, minutes: 40), rec(1, minutes: 30), rec(1.2, minutes: 10), rec(20, minutes: 300)])
    #expect(abs(e.forecast.minutesPerDay - 80.0 / 7) < 1e-9)
    #expect(e.daysPracticed == 2)
}

@Test func usesTestsPassedTowardTheNextLevel() {
    let e = evidence([rec(0)], best: ["g1-0": 95, "g1-1": 92, "g2-0": 91, "g2-3": 99, "g2-4": 70])
    #expect(e.forecast.currentGrade == 1)
    #expect(e.forecast.testsPassed == 2 && e.forecast.testsInNextGrade == 5)
}

@Test func pastGradesComeFromWhenEachLevelWasReached() {
    // Started 90 days ago at 60 min/day, reached level 1 after ~30 days.
    let rs = (0..<90).map { rec(Double($0), minutes: 60) }
    let e = evidence(rs, reached: [(1, now.addingTimeInterval(-60 * 86_400))])
    #expect(e.forecast.pastGrades.count == 1)
    let g = e.forecast.pastGrades[0]
    #expect(g.grade == 1)
    #expect(abs(g.months - 30 / 30.44) < 0.05)
    #expect(abs(g.minutesPerDay - 60) < 3)
}

@Test func averageScoreIsFromTheWindow() {
    #expect(evidence([rec(0, score: 90), rec(2, score: 70), rec(30, score: 10)]).forecast.recentAverageScore == 80)
    #expect(evidence([]).forecast.recentAverageScore == nil)
}

@Test func tempoTrendFromTheMostPractisedExercise() {
    // Paradiddle passed (>90%) at 70, 74, 78 over two weeks: +4 BPM a week.
    let rs = [rec(14, score: 100, bpm: 70), rec(7, score: 100, bpm: 74), rec(0, score: 100, bpm: 78),
              rec(3, score: 50, bpm: 120), rec(1, minutes: 5, score: 100, bpm: 200, id: "other")]
    let e = evidence(rs, window: 30)
    #expect(e.trackedTitle == "Paradiddle")
    #expect(e.forecast.currentBpm == 78)
    #expect(abs((e.forecast.bpmPerWeek ?? 0) - 4) < 1e-6)
}

@Test func noTempoTrendWithoutEnoughCleanRuns() {
    let e = evidence([rec(1, score: 100, bpm: 70), rec(0, score: 100, bpm: 72)], window: 30)
    #expect(e.forecast.bpmPerWeek == nil)
}

@Test func levelsWithoutLoggedPracticeDoNotCountTowardPace() {
    // Level 1 reached 60 days after one short session: nothing logged in between, so it says nothing about pace.
    let e = evidence([rec(90, minutes: 5), rec(0)], reached: [(1, now.addingTimeInterval(-30 * 86_400))])
    #expect(e.forecast.pastGrades.isEmpty)
}
