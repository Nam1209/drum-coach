import DrumAnalysis
import Foundation
import Testing
@testable import DrumAI

private func res(_ kind: String, _ url: String?, query: String = "paradiddle lesson") -> Resource {
    Resource(kind: kind, title: "t", url: url.flatMap(URL.init(string:)), why: "w", searchQuery: query)
}

@Test func deadYouTubeLinkBecomesSearch() async {
    let t = FakeTransport([(404, "")])
    let out = await ResourceValidator(transport: t).validate([res("youtube", "https://www.youtube.com/watch?v=dead")])
    #expect(out[0].url?.absoluteString == "https://www.youtube.com/results?search_query=paradiddle%20lesson")
    #expect(t.requests[0].url!.absoluteString.hasPrefix("https://www.youtube.com/oembed?url="))
}

@Test func liveYouTubeLinkKept() async {
    let t = FakeTransport([(200, #"{"title":"x"}"#)])
    let out = await ResourceValidator(transport: t).validate([res("youtube", "https://www.youtube.com/watch?v=ok")])
    #expect(out[0].url?.absoluteString == "https://www.youtube.com/watch?v=ok")
}

@Test func articleCheckedWithHead() async {
    let t = FakeTransport([(200, ""), (500, "")])
    let out = await ResourceValidator(transport: t).validate([res("article", "https://a.example/ok"), res("article", "https://b.example/bad")])
    #expect(t.requests[0].httpMethod == "HEAD")
    #expect(out[0].url?.host == "a.example")
    #expect(out[1].url?.absoluteString.hasPrefix("https://www.google.com/search?q=") == true)
}

@Test func missingUrlGetsSearchLink() async {
    let out = await ResourceValidator(transport: FakeTransport([])).validate([res("youtube", nil)])
    #expect(out[0].url?.host == "www.youtube.com")
}

@Test func onlyHttpLinksAllowed() async {
    let out = await ResourceValidator(transport: FakeTransport([])).validate([res("article", "javascript:alert(1)")])
    #expect(out[0].url?.scheme == "https")
}

@Test func weeklyReportRequestCarriesContextAndSearch() async throws {
    let body = String(data: try JSONEncoder().encode(TeacherProjectKit.exampleReportJSON), encoding: .utf8)!
    let t = FakeTransport([(200, #"{"content":[{"type":"text","text":\#(body)}],"stop_reason":"end_turn"}"#)])
    let digest = HistorySummarizer.digest([], journal: [], currentLevel: 2, now: Date(), calendar: .current)
    let r = try await Teacher.weeklyReport(digest: digest, profile: StudentProfile(), library: ["L1-singles8": "Single"],
                                           client: ClaudeClient(apiKey: "k", model: "claude-opus-5-5", transport: t))
    #expect(!r.weekPlan.isEmpty)
    let b = t.body()
    #expect((b["tools"] as? [[String: Any]])?.first?["type"] as? String == "web_search_20260209")
    let user = (((b["messages"] as! [[String: Any]])[0]["content"] as! [[String: Any]])[0]["text"] as! String)
    #expect(user.contains("L1-singles8") && user.contains("currentLevel"))
}

@Test func costEstimate() {
    let c = Teacher.estimatedCostUSD(inputBytes: 24_000)
    #expect(c > 0.05 && c < 1.0)
}
