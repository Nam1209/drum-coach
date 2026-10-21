import DrumAnalysis
import Foundation
import Testing
@testable import DrumAI

private func textReply(_ s: String) -> (Int, String) {
    let esc = String(data: try! JSONEncoder().encode(s), encoding: .utf8)!
    return (200, #"{"content":[{"type":"text","text":\#(esc)}],"stop_reason":"end_turn"}"#)
}

@Test func chatKeepsConversation() async throws {
    let t = FakeTransport([textReply("Vì bạn ngắt hơi."), textReply("Tập Count Coach.")])
    let digest = HistorySummarizer.digest([], journal: [], currentLevel: 1, now: Date(), calendar: .current)
    var chat = TeacherChat(client: ClaudeClient(apiKey: "k", model: "m", transport: t), digest: digest, profile: StudentProfile(), lastReport: nil)
    #expect(try await chat.ask("Tại sao tôi trễ ở &?") == "Vì bạn ngắt hơi.")
    #expect(try await chat.ask("Tập gì?") == "Tập Count Coach.")
    let msgs = t.body(1)["messages"] as! [[String: Any]]
    #expect(msgs.count == 3)
    #expect((msgs[1]["content"] as? String) == "Vì bạn ngắt hơi." || ((msgs[1]["content"] as? [[String: Any]])?.first?["text"] as? String) == "Vì bạn ngắt hơi.")
    #expect((t.body(1)["system"] as? String)?.contains("currentLevel") == true)
}

@Test func chatHistoryIsTrimmed() async throws {
    let t = FakeTransport((0..<25).map { textReply("a\($0)") })
    var chat = TeacherChat(client: ClaudeClient(apiKey: "k", model: "m", transport: t),
                           digest: HistorySummarizer.digest([], journal: [], currentLevel: 1, now: Date(), calendar: .current),
                           profile: StudentProfile(), lastReport: nil)
    for i in 0..<25 { _ = try await chat.ask("q\(i)") }
    let msgs = t.body(24)["messages"] as! [[String: Any]]
    #expect(msgs.count <= 21)
    #expect(msgs.first?["role"] as? String == "user")
}

@Test(.vietnamese) func reminderContent() {
    let plan = DayPlan(day: 1, warmup: [PlannedItem(exerciseId: "x", newExerciseDSL: nil, bpm: 60, minutes: 5, focus: "Khởi động")],
                       main: [PlannedItem(exerciseId: "y", newExerciseDSL: nil, bpm: 70, minutes: 20, focus: "Paradiddle 70 BPM")], fun: [])
    let c = ReminderContent.daily(plan)
    #expect(c.body.contains("Paradiddle 70 BPM") && c.body.contains("25 phút"))
    #expect(!ReminderContent.daily(nil).body.isEmpty)
}

@Test func remindersCoverTwoWeeksAhead() {
    #expect(ReminderContent.dayOffsets(practicedToday: true, count: 14) == Array(1...14))
    #expect(ReminderContent.dayOffsets(practicedToday: false, count: 14) == Array(0...13))
}
