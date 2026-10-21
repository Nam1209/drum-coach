import DrumCore
import Foundation

/// One saved practice run, independent of the app's storage.
public struct SessionRecord: Codable, Sendable, Equatable {
    public let date: Date
    public let exerciseId: String
    public let title: String
    public let skill: String
    public let bpm: Double
    public let minutes: Double
    public let score: Double
    public let stats: SessionStats
    public let isLevelTest: Bool

    public init(date: Date, exerciseId: String, title: String, skill: String, bpm: Double, minutes: Double,
                stats: SessionStats, isLevelTest: Bool) {
        self.date = date
        self.exerciseId = exerciseId
        self.title = title
        self.skill = skill
        self.bpm = bpm
        self.minutes = minutes
        score = stats.score
        self.stats = stats
        self.isLevelTest = isLevelTest
    }
}

public struct WeekRollup: Codable, Sendable, Equatable {
    public let weekStart: Date
    public let sessions: Int
    public let minutes: Double
    public let meanScore: Double?
    public let meanOffsetMs: Double?
}

public struct ExerciseTrend: Codable, Sendable, Equatable {
    public let exerciseId: String
    public let title: String
    public let sessions: Int
    public let lastDate: Date
    /// Highest tempo played above 90% overall, and per month ("2026-10").
    public let bestCleanBpm: Double?
    public let bestCleanBpmByMonth: [String: Double]
}

/// Months of history squeezed into a few KB for the AI teacher.
public struct HistoryDigest: Codable, Sendable, Equatable {
    public let totalMinutes: Double
    public let daysPracticed: Int
    public let firstDate: Date?
    public let currentLevel: Int
    public let weekly: [WeekRollup]
    public let perExercise: [ExerciseTrend]
    public let recurringWeaknesses: [String]
    public let last7Days: [SessionRecord]
    public let journal: [String]
    /// Counting-coach runs from the last 14 days (absent in digests made before the coach was scored).
    public var counting: [CountRecord]? = nil
}

public struct LevelMilestone: Codable, Sendable, Equatable {
    public let level: Int
    public let date: Date
}

public struct ExerciseDelta: Codable, Sendable, Equatable {
    public let title: String
    public let cleanBpmStart: Double?
    public let cleanBpmEnd: Double?
}

/// "Where was I three months ago, where am I now?"
public struct PeriodReview: Codable, Sendable, Equatable {
    public let from: Date
    public let to: Date
    public let totalHours: Double
    public let daysPracticed: Int
    public let longestStreak: Int
    public let levelStart: Int
    public let levelEnd: Int
    public let levelsPassed: [LevelMilestone]
    public let exerciseDeltas: [ExerciseDelta]
    public let offsetStartMs: Double?
    public let offsetEndMs: Double?
    public let scoreStart: Double?
    public let scoreEnd: Double?
    public let fixedWeaknesses: [String]
    public let remainingWeaknesses: [String]
}

public enum HistorySummarizer {
    static let weakMs = 20.0
    static let cleanScore = 90.0

    public static func digest(_ records: [SessionRecord], journal: [(Date, String)], counting: [CountRecord] = [], currentLevel: Int,
                              now: Date, calendar: Calendar) -> HistoryDigest {
        let sorted = records.sorted { $0.date < $1.date }
        let days = Set(sorted.map { calendar.startOfDay(for: $0.date) })
        let weekly = (0..<26).reversed().map { k -> WeekRollup in
            let end = now.addingTimeInterval(-Double(k) * 7 * 86_400), start = end.addingTimeInterval(-7 * 86_400)
            let rs = sorted.filter { $0.date >= start && $0.date < end }
            return WeekRollup(weekStart: start, sessions: rs.count, minutes: rs.reduce(0) { $0 + $1.minutes },
                              meanScore: mean(rs.map(\.score)), meanOffsetMs: mean(rs.map(\.stats.meanOffsetMs)))
        }
        let byExercise = Dictionary(grouping: sorted, by: \.exerciseId)
        let monthFmt = DateFormatter()
        monthFmt.calendar = calendar
        monthFmt.timeZone = calendar.timeZone
        monthFmt.dateFormat = "yyyy-MM"
        let trends = byExercise.map { id, rs -> ExerciseTrend in
            let clean = rs.filter { $0.score > cleanScore }
            var byMonth: [String: Double] = [:]
            for r in clean { byMonth[monthFmt.string(from: r.date)] = max(byMonth[monthFmt.string(from: r.date)] ?? 0, r.bpm) }
            return ExerciseTrend(exerciseId: id, title: rs.last!.title, sessions: rs.count, lastDate: rs.last!.date,
                                 bestCleanBpm: clean.map(\.bpm).max(), bestCleanBpmByMonth: byMonth)
        }
        .sorted { $0.lastDate > $1.lastDate }

        let recent = sorted.filter { $0.date >= now.addingTimeInterval(-7 * 86_400) }.suffix(20)
        let notes = journal.filter { $0.0 >= now.addingTimeInterval(-30 * 86_400) }.sorted { $0.0 < $1.0 }.suffix(30)
        let dayFmt = DateFormatter()
        dayFmt.calendar = calendar
        dayFmt.timeZone = calendar.timeZone
        dayFmt.dateFormat = "yyyy-MM-dd"

        return HistoryDigest(totalMinutes: sorted.reduce(0) { $0 + $1.minutes }, daysPracticed: days.count,
                             firstDate: sorted.first?.date, currentLevel: currentLevel, weekly: weekly,
                             perExercise: Array(trends.prefix(30)), recurringWeaknesses: recurringWeaknesses(sorted, now: now),
                             last7Days: Array(recent), journal: notes.map { "\(dayFmt.string(from: $0.0)): \($0.1)" },
                             counting: Array(counting.filter { $0.date >= now.addingTimeInterval(-14 * 86_400) }.sorted { $0.date < $1.date }.suffix(30)))
    }

    /// Weaknesses (counting position, hand, overall early/late) seen in at least 6 of the last 8 weeks.
    static func recurringWeaknesses(_ records: [SessionRecord], now: Date) -> [String] {
        var counts: [String: (weeks: Int, sum: Double)] = [:]
        for k in 0..<8 {
            let end = now.addingTimeInterval(-Double(k) * 7 * 86_400), start = end.addingTimeInterval(-7 * 86_400)
            let rs = records.filter { $0.date >= start && $0.date < end }
            for (key, ms) in weakSpots(rs) {
                let c = counts[key] ?? (0, 0)
                counts[key] = (c.weeks + 1, c.sum + ms)
            }
        }
        return counts.filter { $0.value.weeks >= 6 }.sorted { $0.key < $1.key }.map { key, v in
            describe(key, ms: v.sum / Double(v.weeks)) + L(" trong \(v.weeks)/8 tuần", " in \(v.weeks) of 8 weeks")
        }
    }

    /// Mean offset per counting position / hand / overall across the records, keeping only the weak ones (|ms| ≥ 20).
    static func weakSpots(_ rs: [SessionRecord]) -> [String: Double] {
        guard !rs.isEmpty else { return [:] }
        var groups: [String: [Double]] = [:]
        for r in rs {
            for (label, ms) in r.stats.byBeatPosition { groups["pos:\(label)", default: []].append(ms) }
            for (hand, ms) in r.stats.byHand where hand != .foot { groups["hand:\(hand.rawValue)", default: []].append(ms) }
            groups["all", default: []].append(r.stats.meanOffsetMs)
        }
        return groups.compactMapValues { mean($0) }.filter { abs($0.value) >= weakMs }
    }

    public static func describe(_ key: String, ms: Double) -> String {
        let dir = ms > 0 ? L("trễ", "late") : L("sớm", "early")
        let amount = String(format: "%+.0f ms", ms)
        if key.hasPrefix("pos:") { return "\"\(key.dropFirst(4))\" \(dir) \(amount)" }
        if key.hasPrefix("hand:") {
            let left = key.hasSuffix("L")
            return L("tay \(left ? "trái" : "phải") \(dir) \(amount)", "\(left ? "left" : "right") hand \(dir) \(amount)")
        }
        return L("nhìn chung đánh \(dir) \(amount)", "overall \(dir) \(amount)")
    }

    public static func periodReview(_ records: [SessionRecord], levelHistory: [(Int, Date)], from: Date, to: Date,
                                    calendar: Calendar) -> PeriodReview {
        let rs = records.filter { $0.date >= from && $0.date <= to }.sorted { $0.date < $1.date }
        let days = Array(Set(rs.map { calendar.startOfDay(for: $0.date) })).sorted()
        var longest = 0, run = 0
        for (i, d) in days.enumerated() {
            run = i > 0 && calendar.dateComponents([.day], from: days[i - 1], to: d).day == 1 ? run + 1 : 1
            longest = max(longest, run)
        }
        let twoWeeks = 14.0 * 86_400
        let early = rs.filter { $0.date < from.addingTimeInterval(twoWeeks) }
        let late = rs.filter { $0.date > to.addingTimeInterval(-twoWeeks) }
        let deltas = Dictionary(grouping: rs, by: \.exerciseId).values.map { group -> ExerciseDelta in
            func clean(_ xs: [SessionRecord]) -> Double? { xs.filter { $0.score > cleanScore }.map(\.bpm).max() }
            let id = group[0].exerciseId
            return ExerciseDelta(title: group.last!.title, cleanBpmStart: clean(early.filter { $0.exerciseId == id }),
                                 cleanBpmEnd: clean(late.filter { $0.exerciseId == id }))
        }
        .sorted { $0.title < $1.title }

        let month = 30.0 * 86_400
        let firstMonthSpots = weakSpots(rs.filter { $0.date < from.addingTimeInterval(month) })
        let lastMonthSpots = weakSpots(rs.filter { $0.date > to.addingTimeInterval(-month) })
        let firstMonth = Set(firstMonthSpots.keys)
        let passed = levelHistory.filter { $0.1 >= from && $0.1 <= to }.sorted { $0.1 < $1.1 }
        let before = levelHistory.filter { $0.1 < from }.map(\.0).max() ?? 0
        return PeriodReview(
            from: from, to: to, totalHours: rs.reduce(0) { $0 + $1.minutes } / 60, daysPracticed: days.count, longestStreak: longest,
            levelStart: before, levelEnd: max(before, passed.map(\.0).max() ?? 0),
            levelsPassed: passed.map { LevelMilestone(level: $0.0, date: $0.1) }, exerciseDeltas: deltas,
            offsetStartMs: mean(early.map(\.stats.meanOffsetMs)), offsetEndMs: mean(late.map(\.stats.meanOffsetMs)),
            scoreStart: mean(early.map(\.score)), scoreEnd: mean(late.map(\.score)),
            fixedWeaknesses: firstMonth.subtracting(lastMonthSpots.keys).sorted().map { describe($0, ms: firstMonthSpots[$0]!) },
            remainingWeaknesses: lastMonthSpots.keys.sorted().map { describe($0, ms: lastMonthSpots[$0]!) })
    }

    static func mean(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count) }
}
