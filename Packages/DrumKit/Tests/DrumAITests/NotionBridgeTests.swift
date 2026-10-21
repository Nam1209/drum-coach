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
    let plans = try await bridge.fetchPlans(excluding: ["old"])
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
    let plans = try await NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p").fetchPlans(excluding: [])
    #expect(plans[0].report == .failure(.noJSONBlock))
}

@Test func planWithBrokenJSON() async throws {
    let t = FakeTransport([
        childrenResponse([childPage("p", "Kế hoạch", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([codeBlock("{not json")]),
    ])
    let plans = try await NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p").fetchPlans(excluding: [])
    if case .failure(.invalidJSON) = plans[0].report {} else { Issue.record("expected invalidJSON, got \(plans[0].report)") }
}

@Test func planMissingFields() async throws {
    let t = FakeTransport([
        childrenResponse([childPage("p", "Kế hoạch", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([codeBlock(#"{"summary":"x"}"#)]),
    ])
    let plans = try await NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p").fetchPlans(excluding: [])
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

@Test(.vietnamese) func sendBuildsPromptAndPage() async throws {
    let t = FakeTransport([childrenResponse([]), (200, #"{"id":"r1"}"#)])
    let bridge = NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "inbox", plansPageId: "plans")
    let digest = HistorySummarizer.digest([], journal: [], currentLevel: 1, now: Date(timeIntervalSince1970: 1_792_000_000), calendar: .current)
    let out = try await bridge.send(kind: .weekly, payload: digest, profile: StudentProfile(), date: Date(timeIntervalSince1970: 1_792_000_000))
    #expect(out.pageTitle.hasPrefix("Báo cáo "))
    #expect(out.prompt.contains(out.pageTitle))
    #expect(((t.body(1)["parent"] as! [String: Any])["page_id"] as? String) == "inbox")
}

/// Sending twice on one day updates that day's page instead of adding a second "Báo cáo <day>".
@Test(.vietnamese) func sameDayReportReplacesTheExistingPage() async throws {
    let day = Date(timeIntervalSince1970: 1_792_000_000)
    let title = "Báo cáo \(NotionBridge.dayString(day))"
    let t = FakeTransport([
        childrenResponse([childPage("old-report", title, "2026-10-21T10:00:00.000Z")]),     // inbox
        childrenResponse([codeBlock("{}").replacingOccurrences(of: #"{"type":"code""#, with: #"{"id":"b1","type":"code""#)]),  // its blocks
        (200, "{}"),                                                                          // delete b1
        (200, "{}"),                                                                          // append new content
    ])
    let bridge = NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "inbox", plansPageId: "plans")
    let digest = HistorySummarizer.digest([], journal: [], currentLevel: 1, now: day, calendar: .current)
    let out = try await bridge.send(kind: .weekly, payload: digest, profile: StudentProfile(), date: day)
    #expect(out.pageTitle == title)
    #expect(!t.requests.contains { $0.url!.absoluteString.hasSuffix("/v1/pages") })        // no new page
    #expect(t.requests[2].httpMethod == "DELETE" && t.requests[2].url!.absoluteString.hasSuffix("/blocks/b1"))
    #expect(t.requests[3].httpMethod == "PATCH" && t.requests[3].url!.absoluteString.contains("/blocks/old-report/children"))
    #expect(t.body(3)["children"] != nil)
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
    #expect(try await bridge.fetchExercisePages(excluding: []).flatMap(\.dsl) == [good])
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

@Test func importedPagesAreSkippedByIdNotTime() async throws {
    let t = FakeTransport([
        childrenResponse([childPage("done", "Kế hoạch 1", "2026-10-20T10:00:00.000Z"),
                          childPage("sameMinute", "Kế hoạch 2", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([codeBlock(exampleReport)]),
    ])
    let bridge = NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p")
    let plans = try await bridge.fetchPlans(excluding: ["done"])
    #expect(plans.map(\.pageId) == ["sameMinute"])
}

@Test func failedPageIsReturnedAgainNextTime() async throws {
    let t = FakeTransport([
        childrenResponse([childPage("p1", "Kế hoạch", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([]),                                    // Claude has not written the JSON yet
        childrenResponse([childPage("p1", "Kế hoạch", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([codeBlock(exampleReport)]),
    ])
    let bridge = NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p")
    let first = try await bridge.fetchPlans(excluding: [])
    #expect(first[0].report == .failure(.noJSONBlock))
    let second = try await bridge.fetchPlans(excluding: [])   // caller only excludes successfully imported pages
    if case .success = second[0].report {} else { Issue.record("expected the plan on retry") }
}

@Test func exercisesReportTheirPage() async throws {
    let good = "title: A\ntime: 4/4\ngrid: 1\nSN: xxxx"
    let t = FakeTransport([
        childrenResponse([childPage("e1", "Bài 1", "2026-10-20T10:00:00.000Z"), childPage("e2", "Bài 2", "2026-10-20T10:00:00.000Z")]),
        childrenResponse([codeBlock(good)]),
    ])
    let bridge = NotionBridge(client: NotionClient(token: "s", transport: t), inboxPageId: "i", plansPageId: "p", exercisesPageId: "ex")
    let pages = try await bridge.fetchExercisePages(excluding: ["e2"])
    #expect(pages.map(\.pageId) == ["e1"])
    #expect(pages[0].dsl == [good])
}

@Test(.vietnamese) func guideUsesTheUsersPageNameAndTheirProjectBooks() {
    let text = TeacherProjectKit.projectInstructions(exerciseCatalog: ["start-1": "Móc đơn"], rootTitle: "Drum")
    #expect(text.contains("\"Drum › Hộp thư\""))
    #expect(text.contains("\"Drum › Kế hoạch\""))
    #expect(!text.contains("DrumCoach ›"))
    #expect(text.contains("Rockschool") && text.contains("Stick Control"))
    #expect(text.contains("Tài liệu trong Project"))
    #expect(text.contains("hướng dẫn kỹ thuật"))
}
