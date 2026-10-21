import DrumAnalysis
import Foundation

/// Builds a learner's forecast from their own practice log and level results, and keeps what it was based on
/// so the app can show "based on…".
public struct ForecastEvidence: Sendable {
    public let forecast: ProgressForecast
    public let windowDays: Int
    public let daysPracticed: Int
    /// Exercise whose tempo trend is projected (the most practised one in the window).
    public let trackedTitle: String?

    static let daysPerMonth = 30.44

    public init(records: [SessionRecord], levelReached: [(Int, Date)], progress: LevelProgress, levels: [Level],
                windowDays: Int, now: Date, calendar: Calendar) {
        let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: calendar.startOfDay(for: now)) ?? now
        let recent = records.filter { $0.date >= start && $0.date <= now }
        self.windowDays = windowDays
        daysPracticed = Set(recent.map { calendar.startOfDay(for: $0.date) }).count

        // Tests passed toward the next level.
        let grade = progress.currentLevel
        let next = levels.first { $0.id == grade + 1 }
        let passed = next?.tests.filter(progress.isPassed).count ?? 0

        // How long each level took, and the minutes a day put in meanwhile.
        var past: [ProgressForecast.PastGrade] = []
        var from = records.map(\.date).min()
        for (level, date) in levelReached.sorted(by: { $0.0 < $1.0 }) {
            defer { from = date }
            guard let begin = from, date > begin else { continue }
            let days = date.timeIntervalSince(begin) / 86_400
            guard days >= 1 else { continue }
            let minutes = records.filter { $0.date >= begin && $0.date < date }.reduce(0) { $0 + $1.minutes }
            guard minutes / days >= 1 else { continue }          // practice not logged in the app
            past.append(.init(grade: level, months: days / Self.daysPerMonth, minutesPerDay: minutes / days))
        }

        // Tempo: the best clean (>90%) tempo per day of the most practised exercise, fitted with a straight line.
        let byExercise = Dictionary(grouping: recent, by: \.exerciseId)
        let tracked = byExercise.max { $0.value.reduce(0) { $0 + $1.minutes } < $1.value.reduce(0) { $0 + $1.minutes } }?.value ?? []
        let cleanByDay = Dictionary(grouping: tracked.filter { $0.score > 90 }) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, bpm: $0.value.map(\.bpm).max()!) }.sorted { $0.day < $1.day }
        var bpmPerWeek: Double?
        if cleanByDay.count >= 3, let first = cleanByDay.first, let last = cleanByDay.last,
           last.day.timeIntervalSince(first.day) >= 7 * 86_400 {
            let xs = cleanByDay.map { $0.day.timeIntervalSince(first.day) / (7 * 86_400) }, ys = cleanByDay.map(\.bpm)
            let mx = xs.reduce(0, +) / Double(xs.count), my = ys.reduce(0, +) / Double(ys.count)
            let slope = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) } / xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
            if slope > 0 { bpmPerWeek = slope }
        }
        trackedTitle = tracked.first?.title

        forecast = ProgressForecast(
            minutesPerDay: recent.reduce(0) { $0 + $1.minutes } / Double(max(windowDays, 1)),
            currentGrade: grade, testsPassed: passed, testsInNextGrade: next?.tests.count ?? 0,
            pastGrades: past,
            recentAverageScore: recent.isEmpty ? nil : recent.reduce(0) { $0 + $1.score } / Double(recent.count),
            currentBpm: cleanByDay.last?.bpm, bpmPerWeek: bpmPerWeek)
    }
}
