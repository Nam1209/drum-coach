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

    var stats: SessionStats? { try? JSONDecoder().decode(SessionStats.self, from: statsData) }
}
