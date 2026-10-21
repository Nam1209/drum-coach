import Foundation
import Testing
@testable import DrumAI

@Test func transcriberDropsInvalidDSL() async throws {
    let good = "title: A\ntime: 4/4\ngrid: 1\nSN: xxxx"
    let payload = try JSONEncoder().encode(["exercises": [good, "garbage"]])
    let escaped = String(data: try JSONEncoder().encode(String(data: payload, encoding: .utf8)!), encoding: .utf8)!
    let t = FakeTransport([(200, #"{"content":[{"type":"text","text":\#(escaped)}],"stop_reason":"end_turn"}"#)])
    let out = try await PageTranscriber.transcribe(pagePNG: Data([0]), client: ClaudeClient(apiKey: "k", model: "m", transport: t))
    #expect(out == [good])
}

@Test func transcriberPromptDescribesDSL() {
    #expect(PageTranscriber.instructions.contains("grid:"))
    #expect(PageTranscriber.instructions.contains("ST:"))
}
