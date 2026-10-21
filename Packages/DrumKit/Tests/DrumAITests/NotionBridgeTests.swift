import DrumAnalysis
import Foundation
import Testing
@testable import DrumAI

private let exampleReport = TeacherProjectKit.exampleReportJSON

@Test func longJSONIsSplitIntoRichTextChunks() async throws {
    let t = FakeTransport([(200, #"{"id":"page-1"}"#)])
    let client = NotionClient(token: "secret", transport: t)
    let json = String(repeating: "a", count: 24_000)
    let id = try await client.createChildPage(parent: "inbox", title: "Báo cáo", codeBlockJSON: json)
    #expect(id == "page-1")
    let r = t.requests[0]
    #expect(r.url?.absoluteString == "https://api.notion.com/v1/pages")
    #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    #expect(r.value(forHTTPHeaderField: "Notion-Version") == NotionClient.version)
    let body = t.body()
    let children = body["children"] as! [[String: Any]]
    let pieces = children.flatMap { (($0["code"] as! [String: Any])["rich_text"] as! [[String: Any]]) }
    let texts = pieces.map { ($0["text"] as! [String: Any])["content"] as! String }
    #expect(texts.allSatisfy { $0.count <= 2000 })
    #expect(texts.joined() == json)
    #expect(children.allSatisfy { (($0["code"] as! [String: Any])["rich_text"] as! [Any]).count <= 100 })
}

private func childrenResponse(_ blocks: [String], more: String? = nil) -> (Int, String) {
    (200, #"{"results":[\#(blocks.joined(separator: ","))],"has_more":\#(more != nil),"next_cursor":\#(more.map { "\"\($0)\"" } ?? "null")}"#)
}

private func childPage(_ id: String, _ title: String, _ created: String) -> String {
    #"{"id":"\#(id)","type":"child_page","created_time":"\#(created)","child_page":{"title":"\#(title)"}}"#
}

private func codeBlock(_ text: String) -> String {
    let parts = stride(from: 0, to: text.count, by: 2000).map { i -> String in
        let s = String(text.dropFirst(i).prefix(2000))
        let esc = String(data: try! JSONEncoder().encode(s), encoding: .utf8)!
        return #"{"type":"text","plain_text":\#(esc),"text":{"content":\#(esc)}}"#
    }
    return #"{"type":"code","code":{"language":"json","rich_text":[\#(parts.joined(separator: ","))]}}"#
}

@Test func readsNewPlansOnly() async throws {
    let t = FakeTransport([
        childrenResponse([childPage("old", "Kế hoạch 2026-10-01", "2026-10-01T10:00:00.000Z"),
                          childPage("new", "Kế hoạch 2026-10-20", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([#"{"type":"paragraph","paragraph":{"rich_text":[]}}"#, codeBlock(exampleReport)]),
    ])
    let bridge = NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "inbox", plansPageId: "plans")
    let after = ISO8601DateFormatter().date(from: "2026-10-05T00:00:00Z")
    let plans = try await bridge.fetchNewPlans(after: after)
    #expect(plans.count == 1)
    #expect(plans[0].title == "Kế hoạch 2026-10-20")
    if case .success(let r) = plans[0].report { #expect(!r.weekPlan.isEmpty) } else { Issue.record("expected success") }
    #expect(t.requests[1].url!.absoluteString.contains("/blocks/new/children"))
}

@Test func planWithoutJSONBlock() async throws {
    let t = FakeTransport([
        childrenResponse([childPage("p", "Kế hoạch", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([#"{"type":"paragraph","paragraph":{"rich_text":[]}}"#]),
    ])
    let plans = try await NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p").fetchNewPlans(after: nil)
    #expect(plans[0].report == .failure(.noJSONBlock))
}

@Test func planWithBrokenJSON() async throws {
    let t = FakeTransport([
        childrenResponse([childPage("p", "Kế hoạch", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([codeBlock("{not json")]),
    ])
    let plans = try await NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p").fetchNewPlans(after: nil)
    if case .failure(.invalidJSON) = plans[0].report {} else { Issue.record("expected invalidJSON, got \(plans[0].report)") }
}

@Test func planMissingFields() async throws {
    let t = FakeTransport([
        childrenResponse([childPage("p", "Kế hoạch", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([codeBlock(#"{"summary":"x"}"#)]),
    ])
    let plans = try await NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p").fetchNewPlans(after: nil)
    if case .failure(.schemaMismatch) = plans[0].report {} else { Issue.record("expected schemaMismatch") }
}

@Test func paginationFollowsCursor() async throws {
    let t = FakeTransport([
        childrenResponse([childPage("a", "A", "2026-10-20T10:00:00.000Z")], more: "c2"),
        childrenResponse([childPage("b", "B", "2026-10-21T10:00:00.000Z")]),
    ])
    let pages = try await NotionClient(token: "s", transport: t).childPages(of: "plans")
    #expect(pages.map(\.title) == ["A", "B"])
    #expect(t.requests[1].url!.absoluteString.contains("start_cursor=c2"))
}

@Test func sendBuildsPromptAndPage() async throws {
    let t = FakeTransport([(200, #"{"id":"r1"}"#)])
    let bridge = NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "inbox", plansPageId: "plans")
    let digest = HistorySummarizer.digest([], journal: [], currentLevel: 1, now: Date(timeIntervalSince1970: 1_792_000_000), calendar: .current)
    let out = try await bridge.send(kind: .weekly, payload: digest, profile: StudentProfile(), date: Date(timeIntervalSince1970: 1_792_000_000))
    #expect(out.pageTitle.hasPrefix("Báo cáo "))
    #expect(out.prompt.contains(out.pageTitle))
    #expect(((t.body()["parent"] as! [String: Any])["page_id"] as? String) == "inbox")
}

@Test func instructionsExampleMatchesSchema() throws {
    let r = try JSONDecoder().decode(TeacherReport.self, from: Data(TeacherProjectKit.exampleReportJSON.utf8))
    #expect(r.fixFirst.count <= 3)
    let text = TeacherProjectKit.projectInstructions(exerciseCatalog: ["L1-singles8": "Single stroke móc đơn"])
    #expect(text.contains(TeacherProjectKit.exampleReportJSON))
    #expect(text.contains("L1-singles8"))
    #expect(text.contains("grid:"))
}

@Test func newExercisesAreParsedDSL() async throws {
    let good = "title: A\ntime: 4/4\ngrid: 1\nSN: xxxx"
    let t = FakeTransport([
        childrenResponse([childPage("e", "Bài tập mới 1", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([codeBlock(good), codeBlock("garbage")]),
    ])
    let bridge = NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p", exercisesPageId: "ex")
    #expect(try await bridge.fetchNewExercises(after: nil) == [good])
}

@Test func bigPayloadIsSentInRequestsUnderNotionLimit() async throws {
    let json = String(repeating: "b", count: 1_200_000)
    let t = FakeTransport(Array(repeating: (200, #"{"id":"page-x","results":[]}"#), count: 20))
    let id = try await NotionClient(token: "s", transport: t).createChildPage(parent: "inbox", title: "Backup", codeBlockJSON: json)
    #expect(id == "page-x")
    #expect(t.requests.count > 1)
    #expect(t.requests.allSatisfy { ($0.httpBody?.count ?? 0) < 450_000 })
    #expect(t.requests.dropFirst().allSatisfy { $0.httpMethod == "PATCH" && $0.url!.absoluteString.hasSuffix("/blocks/page-x/children") })
    var joined = ""
    for i in t.requests.indices {
        let children = t.body(i)["children"] as! [[String: Any]]
        for c in children { for r in ((c["code"] as! [String: Any])["rich_text"] as! [[String: Any]]) { joined += (r["text"] as! [String: Any])["content"] as! String } }
    }
    #expect(joined == json)
}
