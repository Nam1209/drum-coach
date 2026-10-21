import DrumCore
import Foundation
import Testing
@testable import DrumAnalysis

private let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
private let now = Date(timeIntervalSince1970: 1_792_000_000)

/// Stats of 8 eighth notes; "&" notes offset by `andMs`, numbers by 0; all hits (score 100 or orange).
func eighthStats(andMs: Double, numberMs: Double = 0) -> SessionStats {
    let notes = (0..<8).map { TimedNote(index: $0, noteIndex: $0, repeatIndex: 0,
                                        note: NoteEvent(position: Rational($0, 2), voice: .snare, hand: $0 % 2 == 0 ? .right : .left),
                                        time: Double($0) * 0.5) }
    var r: [Int: NoteResult] = [:]
    for i in 0..<8 { r[i] = .hit(offset: (i % 2 == 1 ? andMs : numberMs) / 1000, velocity: 0.8) }
    return SessionStats(results: r, notes: notes, extraHits: 0)
}

func record(daysAgo: Double, bpm: Double, andMs: Double = 0, exercise: String = "A") -> SessionRecord {
    SessionRecord(date: now.addingTimeInterval(-daysAgo * 86_400), exerciseId: exercise, title: "Bài \(exercise)", skill: "Rudiments",
                  bpm: bpm, minutes: 5, stats: eighthStats(andMs: andMs), isLevelTest: false)
}

@Test func twoYearsFitsInDigest() throws {
    var rs: [SessionRecord] = []
    for d in 0..<730 { for k in 0..<2 { rs.append(record(daysAgo: Double(d) + Double(k) * 0.1, bpm: 60 + Double(730 - d) / 20, exercise: k == 0 ? "A" : "B")) } }
    let digest = HistorySummarizer.digest(rs, journal: [], currentLevel: 2, now: now, calendar: cal)
    #expect(digest.weekly.count == 26)
    #expect(digest.daysPracticed == 730)
    let size = try JSONEncoder().encode(digest).count
    #expect(size < 24_000, "digest is \(size) bytes")
}

@Test func recurringWeaknessNeedsSixOfEightWeeks() {
    var rs: [SessionRecord] = []
    for w in 0..<8 { rs.append(record(daysAgo: Double(w * 7) + 1, bpm: 70, andMs: w < 6 ? 30 : 0)) }
    let d = HistorySummarizer.digest(rs, journal: [], currentLevel: 1, now: now, calendar: cal)
    #expect(d.recurringWeaknesses.contains { $0.contains("\"&\"") && $0.contains("6/8") })

    let once = [record(daysAgo: 1, bpm: 70, andMs: 30)] + (1..<8).map { record(daysAgo: Double($0 * 7) + 1, bpm: 70) }
    #expect(HistorySummarizer.digest(once, journal: [], currentLevel: 1, now: now, calendar: cal).recurringWeaknesses.isEmpty)
}

@Test func emptyHistory() {
    let d = HistorySummarizer.digest([], journal: [], currentLevel: 0, now: now, calendar: cal)
    #expect(d.totalMinutes == 0 && d.daysPracticed == 0 && d.firstDate == nil && d.last7Days.isEmpty)
}

@Test func cleanTempoOnlyFromScoresAboveNinety() {
    let good = record(daysAgo: 2, bpm: 80)
    let sloppy = SessionRecord(date: now.addingTimeInterval(-86_400), exerciseId: "A", title: "Bài A", skill: "R", bpm: 95,
                               minutes: 5, stats: eighthStats(andMs: 60), isLevelTest: false)
    let d = HistorySummarizer.digest([good, sloppy], journal: [], currentLevel: 1, now: now, calendar: cal)
    #expect(d.perExercise.first { $0.exerciseId == "A" }?.bestCleanBpm == 80)
}

@Test func journalKeepsLast30Days() {
    let d = HistorySummarizer.digest([], journal: [(now.addingTimeInterval(-86_400), "mỏi tay trái"), (now.addingTimeInterval(-40 * 86_400), "cũ")],
                                     currentLevel: 0, now: now, calendar: cal)
    #expect(d.journal.count == 1 && d.journal[0].contains("mỏi tay trái"))
}

@Test func periodReviewShowsProgress() {
    var rs: [SessionRecord] = []
    for day in 0..<90 {
        let bpm = 60 + Double(day) * 24 / 89          // 60 → 84 over 90 days
        rs.append(record(daysAgo: Double(89 - day), bpm: bpm.rounded(), andMs: day < 30 ? 30 : 0))
    }
    let from = now.addingTimeInterval(-90 * 86_400)
    let r = HistorySummarizer.periodReview(rs, levelHistory: [(1, now.addingTimeInterval(-60 * 86_400))], from: from, to: now, calendar: cal)
    let a = r.exerciseDeltas.first { $0.title == "Bài A" }
    #expect(a?.cleanBpmEnd ?? 0 >= 82)
    #expect(a?.cleanBpmStart ?? 100 <= 64)
    #expect(r.fixedWeaknesses.contains { $0.contains("\"&\"") })
    #expect(r.remainingWeaknesses.isEmpty)
    #expect(r.levelsPassed.map(\.level) == [1])
    #expect(r.daysPracticed == 90)
}

@Test func periodReviewWithNoData() {
    let r = HistorySummarizer.periodReview([], levelHistory: [], from: now.addingTimeInterval(-86_400 * 90), to: now, calendar: cal)
    #expect(r.totalHours == 0 && r.exerciseDeltas.isEmpty && r.longestStreak == 0)
}
