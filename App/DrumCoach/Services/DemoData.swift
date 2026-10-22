#if DEBUG
import DrumAnalysis
import DrumCore
import Foundation
import SwiftData

/// `-demoData` launch argument (DEBUG only): fills an empty store with 60 days of plausible practice,
/// so screens that need history (forecast, charts, journey) can be checked on the simulator.
enum DemoData {
    @MainActor
    static func seedIfRequested(_ ctx: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-demoData"),
              (try? ctx.fetchCount(FetchDescriptor<PracticeSession>())) == 0 else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ n: Int) -> Date { cal.date(byAdding: .hour, value: 19, to: cal.date(byAdding: .day, value: -n, to: today)!)! }

        for n in stride(from: 59, through: 0, by: -1) where n % 4 != 3 {
            let progress = Double(59 - n) / 59
            let score = Int((70 + progress * 20 + (n % 2 == 0 ? 6 : -4)).rounded())
            let bpm = (60 + progress * 14).rounded()
            insert(ctx, day(n), "Paradiddle", bpm: bpm, minutes: 25 + Double(n % 3) * 8, score: score)
            insert(ctx, day(n).addingTimeInterval(1800), "Single Strokes", bpm: 70, minutes: 10, score: score + 4)
        }
        let levels = BookLibrary.levels.sorted { $0.id < $1.id }
        for (level, daysAgo, count) in [(0, 45, Int.max), (1, 15, Int.max), (2, 3, 2)] where level < levels.count {
            for t in levels[level].tests.prefix(count) {
                insert(ctx, day(daysAgo), t.id, bpm: t.bpm, minutes: 1, score: 95, testId: t.id)
            }
        }
        SettingsStore.markLevelReached(1, at: day(45))
        SettingsStore.markLevelReached(2, at: day(15))
        SettingsStore.currentGrade = 2
        try? ctx.save()
    }

    private static func insert(_ ctx: ModelContext, _ date: Date, _ title: String, bpm: Double, minutes: Double, score: Int, testId: String? = nil) {
        ctx.insert(PracticeSession(date: date, exerciseId: title, title: title, skill: "", bpm: bpm, seconds: minutes * 60, mode: "pad",
                                   goodWindowMs: 30, stats: stats(score), isLevelTest: testId != nil, levelTestId: testId))
    }

    /// Stats scoring `percent` (20 notes, the rest missed).
    private static func stats(_ percent: Int) -> SessionStats {
        let notes = (0..<20).map { TimedNote(index: $0, noteIndex: $0, repeatIndex: 0, note: NoteEvent(position: Rational($0, 2), voice: .snare), time: Double($0) / 2) }
        var results: [Int: NoteResult] = [:]
        let good = min(20, max(0, percent / 5))
        for i in 0..<20 { results[i] = i < good ? .hit(offset: Double(i % 3 - 1) * 0.008, velocity: 0.8) : .missed }
        return SessionStats(results: results, notes: notes, extraHits: 0)
    }
}
#endif
