import Foundation
import Testing
@testable import DrumAI

final class FakeTransport: HTTPTransport, @unchecked Sendable {
    var responses: [(Int, String)]
    var requests: [URLRequest] = []
    var error: Error?
    init(_ responses: [(Int, String)]) { self.responses = responses }
    func send(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(req)
        if let error { throw error }
        let (status, body) = responses.removeFirst()
        return (Data(body.utf8), HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
    func body(_ i: Int = 0) -> [String: Any] {
        try! JSONSerialization.jsonObject(with: requests[i].httpBody!) as! [String: Any]
    }
}

struct Answer: Decodable, Equatable, Sendable { let value: Int }
private let schema: JSONValue = .object(["type": .string("object"), "properties": .object(["value": .object(["type": .string("integer")])]),
                                          "required": .array([.string("value")]), "additionalProperties": .bool(false)])

private func ok(_ text: String, stop: String = "end_turn") -> (Int, String) {
    let escaped = String(data: try! JSONEncoder().encode(text), encoding: .utf8)!
    return (200, #"{"content":[{"type":"text","text":\#(escaped)}],"stop_reason":"\#(stop)"}"#)
}

@Test func requestShape() async throws {
    let t = FakeTransport([ok(#"{"value": 7}"#)])
    let c = ClaudeClient(apiKey: "sk-test", model: "claude-opus-5-5", transport: t)
    let a = try await c.structured(system: "sys", content: [.text("hi")], schema: schema, as: Answer.self, effort: .high, webSearch: false, maxTokens: 1000)
    #expect(a == Answer(value: 7))
    let r = t.requests[0]
    #expect(r.value(forHTTPHeaderField: "x-api-key") == "sk-test")
    #expect(r.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    #expect(r.value(forHTTPHeaderField: "anthropic-beta") == "server-side-fallback-2026-07-01")
    let b = t.body()
    #expect(b["model"] as? String == "claude-opus-5-5")
    #expect((b["thinking"] as? [String: Any])?["type"] as? String == "adaptive")
    #expect(((b["output_config"] as? [String: Any])?["format"] as? [String: Any])?["type"] as? String == "json_schema")
    #expect((b["output_config"] as? [String: Any])?["effort"] as? String == "high")
    #expect(b["fallbacks"] as? String == "default")
    #expect(b["tool_choice"] == nil)
    #expect(b["tools"] == nil)
}

@Test func webSearchToolAdded() async throws {
    let t = FakeTransport([ok(#"{"value": 1}"#)])
    _ = try await ClaudeClient(apiKey: "k", model: "claude-opus-5-5", transport: t)
        .structured(system: "s", content: [.text("q")], schema: schema, as: Answer.self, effort: .medium, webSearch: true, maxTokens: 100)
    let tools = t.body()["tools"] as? [[String: Any]]
    #expect(tools?.first?["type"] as? String == "web_search_20260209")
    #expect(tools?.first?["name"] as? String == "web_search")
}

@Test func imageBlockEncoded() async throws {
    let t = FakeTransport([ok(#"{"value": 1}"#)])
    _ = try await ClaudeClient(apiKey: "k", model: "m", transport: t)
        .structured(system: "s", content: [.imagePNG(Data([1, 2, 3])), .text("q")], schema: schema, as: Answer.self, effort: .low, webSearch: false, maxTokens: 100)
    let msg = (t.body()["messages"] as! [[String: Any]])[0]
    let first = (msg["content"] as! [[String: Any]])[0]
    #expect(first["type"] as? String == "image")
    #expect((first["source"] as? [String: Any])?["data"] as? String == Data([1, 2, 3]).base64EncodedString())
}

@Test func httpErrorSurfaced() async {
    let t = FakeTransport([(401, #"{"error":{"message":"invalid x-api-key"}}"#)])
    await #expect(throws: ClaudeError.http(401, "invalid x-api-key")) {
        _ = try await ClaudeClient(apiKey: "bad", model: "m", transport: t)
            .structured(system: "s", content: [.text("q")], schema: schema, as: Answer.self, effort: .low, webSearch: false, maxTokens: 10)
    }
}

@Test func refusalSurfaced() async {
    let t = FakeTransport([(200, #"{"content":[],"stop_reason":"refusal","stop_details":{"type":"refusal","explanation":"nope"}}"#)])
    await #expect(throws: ClaudeError.refused("nope")) {
        _ = try await ClaudeClient(apiKey: "k", model: "m", transport: t)
            .structured(system: "s", content: [.text("q")], schema: schema, as: Answer.self, effort: .low, webSearch: false, maxTokens: 10)
    }
}

@Test func badJSONIsDecodingError() async {
    let t = FakeTransport([ok(#"{"valu": "x"}"#)])
    await #expect {
        _ = try await ClaudeClient(apiKey: "k", model: "m", transport: t)
            .structured(system: "s", content: [.text("q")], schema: schema, as: Answer.self, effort: .low, webSearch: false, maxTokens: 10)
    } throws: { if case ClaudeError.decoding = $0 { true } else { false } }
}

@Test func networkFailure() async {
    let t = FakeTransport([])
    t.error = URLError(.notConnectedToInternet)
    await #expect {
        _ = try await ClaudeClient(apiKey: "k", model: "m", transport: t)
            .structured(system: "s", content: [.text("q")], schema: schema, as: Answer.self, effort: .low, webSearch: false, maxTokens: 10)
    } throws: { if case ClaudeError.network = $0 { true } else { false } }
}

@Test func missingKey() async {
    await #expect(throws: ClaudeError.missingKey) {
        _ = try await ClaudeClient(apiKey: "", model: "m", transport: FakeTransport([]))
            .structured(system: "s", content: [.text("q")], schema: schema, as: Answer.self, effort: .low, webSearch: false, maxTokens: 10)
    }
}

@Test func pauseTurnIsContinued() async throws {
    let paused = (200, #"{"content":[{"type":"server_tool_use","id":"s1","name":"web_search","input":{"query":"x"}}],"stop_reason":"pause_turn"}"#)
    let t = FakeTransport([paused, ok(#"{"value": 3}"#)])
    let a = try await ClaudeClient(apiKey: "k", model: "m", transport: t)
        .structured(system: "s", content: [.text("q")], schema: schema, as: Answer.self, effort: .low, webSearch: true, maxTokens: 10)
    #expect(a.value == 3)
    #expect(t.requests.count == 2)
    let msgs = t.body(1)["messages"] as! [[String: Any]]
    #expect(msgs.count == 2)
    #expect(msgs[1]["role"] as? String == "assistant")
}
