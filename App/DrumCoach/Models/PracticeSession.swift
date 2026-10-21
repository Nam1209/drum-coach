import DrumAnalysis
import Foundation
import SwiftData

/// One run of an exercise. Saved from the very first session so the AI teacher has the full history.
@Model
final class PracticeSession {
    var id: UUID
    var date: Date
    var exerciseId: String
    var title: String
    var skill: String
    var bpm: Double
    var seconds: Double
    var mode: String
    var goodWindowMs: Double
    var score: Double
    var statsData: Data
    var isLevelTest: Bool
    var levelTestId: String?
    var assessmentData: Data?
    /// Played to the last note rather than stopped early (earns the completion bonus).
    var completed: Bool = false

    init(date: Date, exerciseId: String, title: String, skill: String, bpm: Double, seconds: Double, mode: String,
         goodWindowMs: Double, stats: SessionStats, isLevelTest: Bool = false, levelTestId: String? = nil) {
        id = UUID()
        self.date = date
        self.exerciseId = exerciseId
        self.title = title
        self.skill = skill
        self.bpm = bpm
        self.seconds = seconds
        self.mode = mode
        self.goodWindowMs = goodWindowMs
        score = stats.score
        statsData = (try? JSONEncoder().encode(stats)) ?? Data()
        self.isLevelTest = isLevelTest
        self.levelTestId = levelTestId
    }

    /// Points this run earned or cost (derived, so the rule can change without migrating data).
    var points: Int {
        PracticePoints.points(score: score, goodWindowMs: goodWindowMs, isLevelTest: isLevelTest, seconds: seconds,
                              missedFraction: missedFraction, completed: completed)
    }

    /// Share of the notes the app never heard (1 = it heard nothing, usually a mic or connection problem).
    var missedFraction: Double {
        guard let st = stats, st.totalNotes > 0 else { return 0 }
        return Double(st.missed) / Double(st.totalNotes)
    }

    var stats: SessionStats? { try? JSONDecoder().decode(SessionStats.self, from: statsData) }
}
