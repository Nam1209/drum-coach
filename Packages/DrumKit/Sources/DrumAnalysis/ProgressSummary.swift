import Foundation

/// Numbers for the progress screen: streak, practice time, clean tempo over time, weakest counting position.
public struct ProgressSummary: Sendable {
    let records: [SessionRecord]
    let now: Date
    let calendar: Calendar

    public init(records: [SessionRecord], now: Date, calendar: Calendar) {
        self.records = records.sorted { $0.date < $1.date }
        self.now = now
        self.calendar = calendar
    }

    /// Consecutive practice days ending today (or yesterday, if today has no practice yet).
    public var streakDays: Int {
        let days = Set(records.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while days.contains(day) {
            n += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    /// Minutes practised in the last 7 days.
    public var minutesThisWeek: Double {
        records.filter { now.timeIntervalSince($0.date) < 7 * 86_400 }.reduce(0) { $0 + $1.minutes }
    }

    /// Highest tempo at which the exercise scored above `minScore`.
    public func bestCleanTempo(exerciseId: String, minScore: Double) -> Double? {
        records.filter { $0.exerciseId == exerciseId && $0.score > minScore }.map(\.bpm).max()
    }

    /// Best clean tempo per day, for a line chart.
    public func cleanTempoSeries(exerciseId: String, minScore: Double = 90) -> [(date: Date, bpm: Double)] {
        let byDay = Dictionary(grouping: records.filter { $0.exerciseId == exerciseId && $0.score > minScore }) { calendar.startOfDay(for: $0.date) }
        return byDay.map { ($0.key, $0.value.map(\.bpm).max()!) }.sorted { $0.date < $1.date }
    }

    /// Mean offset per counting position over the last 30 days.
    public var offsetByPosition: [String: Double] {
        var groups: [String: [Double]] = [:]
        for r in records where now.timeIntervalSince(r.date) < 30 * 86_400 {
            for (k, v) in r.stats.byBeatPosition { groups[k, default: []].append(v) }
        }
        return groups.mapValues { $0.reduce(0, +) / Double($0.count) }
    }

    /// The counting position with the largest mean offset (≥ 10 ms) in the last 30 days.
    public var weakestBeatPosition: String? {
        offsetByPosition.filter { abs($0.value) >= 10 }.max { abs($0.value) < abs($1.value) }?.key
    }

    public var exerciseIds: [(id: String, title: String)] {
        var seen: [String: String] = [:]
        for r in records { seen[r.exerciseId] = r.title }
        return seen.map { ($0.key, $0.value) }.sorted { $0.title < $1.title }
    }
}
