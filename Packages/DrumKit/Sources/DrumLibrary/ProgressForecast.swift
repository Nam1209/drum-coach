import Foundation

/// Where a learner is likely to be in a few months, from their own record rather than averages alone:
/// time practised, tests already passed, how fast past grades went, how clean recent runs were, and their tempo trend.
/// Rules of thumb, not measurements: the app shows them as estimates.
public struct ProgressForecast: Sendable {
    public struct PastGrade: Sendable, Hashable {
        public let grade: Int
        public let months: Double
        public let minutesPerDay: Double
        public init(grade: Int, months: Double, minutesPerDay: Double) {
            self.grade = grade; self.months = months; self.minutesPerDay = minutesPerDay
        }
    }

    public let minutesPerDay: Double
    public let currentGrade: Int
    public let testsPassed: Int
    public let testsInNextGrade: Int
    public let pastGrades: [PastGrade]
    public let recentAverageScore: Double?
    public let currentBpm: Double?
    public let bpmPerWeek: Double?
    /// Minutes a day behind `bpmPerWeek` (so a different budget can be compared fairly).
    private let measuredMinutes: Double

    public init(minutesPerDay: Double, currentGrade: Int, testsPassed: Int, testsInNextGrade: Int,
                pastGrades: [PastGrade], recentAverageScore: Double?, currentBpm: Double?, bpmPerWeek: Double?) {
        self.minutesPerDay = minutesPerDay
        self.currentGrade = currentGrade
        self.testsPassed = testsPassed
        self.testsInNextGrade = testsInNextGrade
        self.pastGrades = pastGrades
        self.recentAverageScore = recentAverageScore
        self.currentBpm = currentBpm
        self.bpmPerWeek = bpmPerWeek
        measuredMinutes = minutesPerDay
    }

    /// The same learner practising a different amount each day.
    public func with(minutesPerDay m: Double) -> ProgressForecast { ProgressForecast(copy: self, minutes: m) }

    private init(copy f: ProgressForecast, minutes: Double) {
        minutesPerDay = minutes; currentGrade = f.currentGrade; testsPassed = f.testsPassed; testsInNextGrade = f.testsInNextGrade
        pastGrades = f.pastGrades; recentAverageScore = f.recentAverageScore; currentBpm = f.currentBpm; bpmPerWeek = f.bpmPerWeek
        measuredMinutes = f.measuredMinutes
    }

    /// Typical months per grade (Grades up to 5) at an average of `m` minutes a day, days off included.
    public static func typicalMonthsPerGrade(minutes m: Double) -> Double {
        let points: [(Double, Double)] = [(15, 10), (30, 5.5), (60, 3.5), (120, 2.5), (240, 2)]
        if m <= 15 { return 10 * 15 / max(m, 5) }
        for (a, b) in zip(points, points.dropFirst()) where m <= b.0 {
            return a.1 + (b.1 - a.1) * (m - a.0) / (b.0 - a.0)
        }
        return 2
    }
    private static func weight(_ grade: Int) -> Double { grade >= 6 ? 1.5 : 1 }

    /// Below 1: this learner has finished grades faster than typical for the time they put in.
    public var paceFactor: Double {
        guard !pastGrades.isEmpty else { return 1 }
        let actual = pastGrades.reduce(0) { $0 + $1.months }
        let expected = pastGrades.reduce(0) { $0 + Self.typicalMonthsPerGrade(minutes: $1.minutesPerDay) * Self.weight($1.grade) }
        return min(2, max(0.5, actual / expected))
    }

    /// Clean practice sticks; sloppy repetition has to be unlearned.
    public var qualityFactor: Double {
        guard let s = recentAverageScore else { return 1 }
        return s >= 90 ? 0.9 : s >= 75 ? 1.0 : s >= 60 ? 1.2 : 1.5
    }

    /// Grade position after `months`: 3.4 means Grade 3 reached and 40% of the way to Grade 4.
    public func position(afterMonths months: Double) -> Double {
        var g = Double(currentGrade) + (testsInNextGrade > 0 ? Double(min(testsPassed, testsInNextGrade)) / Double(testsInNextGrade) : 0)
        var left = months
        let perGrade = Self.typicalMonthsPerGrade(minutes: minutesPerDay) * paceFactor * qualityFactor
        while left > 1e-12, g < 8 {
            let next = floor(g) + 1, cost = perGrade * Self.weight(Int(next)), need = (next - g) * cost
            if left >= need { g = next; left -= need } else { g += left / cost; left = 0 }
        }
        return min(g, 8)
    }

    /// Tempo after `months` if the measured weekly gain continues, tapering off (3% less each week), at most +60 BPM.
    public func bpm(afterMonths months: Double) -> Int? {
        guard let currentBpm, let bpmPerWeek, bpmPerWeek > 0 else { return nil }
        let perWeek = bpmPerWeek * (minutesPerDay / max(measuredMinutes, 5)).squareRoot()
        let weeks = months * 52 / 12
        let gain = perWeek * (1 - pow(0.97, weeks)) / 0.03
        return Int((currentBpm + min(gain, 60)).rounded())
    }
}
