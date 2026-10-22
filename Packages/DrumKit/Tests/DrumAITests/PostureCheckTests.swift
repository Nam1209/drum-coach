import Foundation
import Testing
@testable import DrumAI

@Test func framesSpreadAfterCountIn() {
    let f = PostureCheck.pickFrames(count: 4, duration: 60, avoidFirst: 4)
    #expect(f.count == 4)
    #expect(zip(f, f.dropFirst()).allSatisfy { $0 < $1 })
    #expect(f.allSatisfy { $0 >= 4 && $0 < 60 })
}

@Test func tooShortGivesNoFrames() {
    #expect(PostureCheck.pickFrames(count: 4, duration: 3, avoidFirst: 4).isEmpty)
}

@Test func checklistAndPrompt() {
    #expect(PostureCheck.checklist.count >= 8)
    let p = PostureCheck.prompt(exercise: "Paradiddle", date: Date(timeIntervalSince1970: 1_792_000_000))
    #expect(p.contains("Paradiddle") && p.contains(PostureCheck.checklist[0]))
}

@Test func postureReviewRequestHasImages() async throws {
    let body = String(data: try JSONEncoder().encode(#"{"good":["a"],"fix":["b"],"drill":"c"}"#), encoding: .utf8)!
    let t = FakeTransport([(200, #"{"content":[{"type":"text","text":\#(body)}],"stop_reason":"end_turn"}"#)])
    let r = try await PostureCheck.review(frames: [Data([1]), Data([2])], exercise: "X", client: ClaudeClient(apiKey: "k", model: "m", transport: t))
    #expect(r.fix == ["b"])
    let content = ((t.body()["messages"] as! [[String: Any]])[0]["content"] as! [[String: Any]])
    #expect(content.filter { $0["type"] as? String == "image" }.count == 2)
}
