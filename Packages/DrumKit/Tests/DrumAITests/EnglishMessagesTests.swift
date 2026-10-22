import DrumAnalysis
import DrumCore
import DrumLibrary
import Foundation
import Testing
@testable import DrumAI

private let marks = Set("àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ")
private func vietnamese(_ s: String) -> Bool { s.lowercased().contains { marks.contains($0) } }

@Test func englishMessagesHaveNoVietnamese() async throws {
    try await Lang.$override.withValue(.en) {
        var texts: [String] = []
        texts += [ClaudeError.missingKey, .network("x"), .http(401, ""), .http(429, ""), .http(503, ""), .http(418, ""), .refused(nil), .decoding("x")].map(\.userMessage)
        texts += [NotionError.http(401, ""), .http(404, ""), .http(413, ""), .http(429, ""), .http(500, ""), .badResponse].map(\.userMessage)
        texts += [BridgeError.noJSONBlock, .invalidJSON(""), .schemaMismatch("")].map(\.userMessage)
        let r = ReminderContent.daily(nil); texts += [r.title, r.body, ReminderContent.weekly.title, ReminderContent.weekly.body]
        texts += PostureCheck.checklist + [PostureCheck.prompt(exercise: "X", date: Date())]
        for g in 1...8 { for q in GMQuiz.questions(grade: g, seed: 1) { texts += [q.text] + q.options } }
        let notes = (0..<8).map { TimedNote(index: $0, noteIndex: $0, repeatIndex: 0, note: NoteEvent(position: Rational($0, 2), voice: .snare, hand: $0 % 2 == 0 ? .right : .left), time: Double($0) / 2) }
        var res: [Int: NoteResult] = [:]
        for i in 0..<8 { res[i] = i < 3 ? .missed : .hit(offset: 0.04, velocity: 0.8) }
        let stats = SessionStats(results: res, notes: notes, extraHits: 0)
        let a = AssessmentRequest.localFallback(AssessmentInput(exerciseTitle: "X", skill: "Y", grade: 2, bpm: 60, targetBpm: 70, stats: stats, recentHistory: [], mode: "pad"))
        texts += [a.timingComment] + a.strengths + a.weaknesses + a.nextSteps
        texts += [AssessmentRequest.systemPrompt, Teacher.systemPrompt, PageTranscriber.instructions,
                  TeacherProjectKit.projectInstructions(exerciseCatalog: ["a": "b"])]
        texts += [HistorySummarizer.describe("pos:&", ms: 30), HistorySummarizer.describe("hand:L", ms: -25), HistorySummarizer.describe("all", ms: 22)]
        texts.append(NotionBridge.Kind.weekly.title)
        let bad = texts.filter(vietnamese)
        #expect(bad.isEmpty, "\(bad.map { String($0.prefix(80)) })")
    }
}
