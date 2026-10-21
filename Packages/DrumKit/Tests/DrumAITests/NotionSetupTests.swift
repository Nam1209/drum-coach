import Foundation
import Testing
@testable import DrumAI

private func searchResponse(_ pages: [(id: String, title: String)], parents: [String: String] = [:]) -> (Int, String) {
    let items = pages.map { p in
        let parent = parents[p.id].map { #"{"type":"page_id","page_id":"\#($0)"}"# } ?? #"{"type":"workspace","workspace":true}"#
        return #"{"object":"page","id":"\#(p.id)","parent":\#(parent),"properties":{"title":{"type":"title","title":[{"plain_text":"\#(p.title)"}]}}}"#
    }
    return (200, #"{"results":[\#(items.joined(separator: ","))],"has_more":false,"next_cursor":null}"#)
}

private func children(_ pages: [(id: String, title: String)]) -> (Int, String) {
    let items = pages.map { #"{"id":"\#($0.id)","type":"child_page","created_time":"2026-10-20T10:00:00.000Z","child_page":{"title":"\#($0.title)"}}"# }
    return (200, #"{"results":[\#(items.joined(separator: ","))],"has_more":false,"next_cursor":null}"#)
}

private let titles = NotionSetup.Titles(inbox: "Hộp thư", plans: "Kế hoạch", exercises: "Bài tập mới")

@Test func connectFindsTheSharedPageAndCreatesOnlyMissingSubpages() async throws {
    let t = FakeTransport([
        searchResponse([("other", "Ghi chú"), ("root", "DrumCoach")]),
        children([("inbox-1", "Hộp thư")]),            // inbox already there (reconnecting)
        (200, #"{"id":"plans-1"}"#),
        (200, #"{"id":"ex-1"}"#),
    ])
    let ws = try await NotionSetup.connect(client: NotionClient(token: "s", transport: t), titles: titles)
    #expect(ws == NotionWorkspace(root: "root", rootTitle: "DrumCoach", inbox: "inbox-1", plans: "plans-1", exercises: "ex-1"))
    #expect(t.requests[0].url!.absoluteString.hasSuffix("/v1/search"))
    #expect(t.requests[1].url!.absoluteString.contains("/blocks/root/children"))
    #expect(t.requests.count == 4)
    #expect(((t.body(2)["parent"] as! [String: Any])["page_id"] as! String) == "root")
}

@Test func connectFallsBackToTheOnlySharedPage() async throws {
    let t = FakeTransport([searchResponse([("p", "Trống của Nam")]), children([("a", "Hộp thư"), ("b", "Kế hoạch"), ("c", "Bài tập mới")])])
    let ws = try await NotionSetup.connect(client: NotionClient(token: "s", transport: t), titles: titles)
    #expect(ws == NotionWorkspace(root: "p", rootTitle: "Trống của Nam", inbox: "a", plans: "b", exercises: "c"))
}

@Test func connectWithoutAnySharedPageSaysSo() async throws {
    let t = FakeTransport([searchResponse([])])
    await #expect(throws: NotionError.noSharedPage) {
        try await NotionSetup.connect(client: NotionClient(token: "s", transport: t), titles: titles)
    }
}

@Test func publishingTheGuideReplacesTheOldOneOnlyAfterTheNewOneExists() async throws {
    let t = FakeTransport([children([("g-old", "Hướng dẫn cho thầy"), ("i", "Hộp thư")]), (200, #"{"id":"g-new"}"#), (200, "{}")])
    let id = try await NotionSetup.publishGuide(client: NotionClient(token: "s", transport: t), root: "root",
                                                title: "Hướng dẫn cho thầy", text: "Bạn là thầy dạy trống")
    #expect(id == "g-new")
    let code = ((t.body(1)["children"] as! [[String: Any]])[0]["code"] as! [String: Any])
    #expect(code["language"] as? String == "markdown")
    #expect(t.requests[2].url!.absoluteString.hasSuffix("/pages/g-old"))
    #expect(t.requests[2].httpMethod == "PATCH")
    #expect(t.body(2)["archived"] as? Bool == true)
}

@Test func aFailedPublishKeepsTheOldGuide() async throws {
    let t = FakeTransport([children([("g-old", "Hướng dẫn cho thầy")]), (400, #"{"message":"bad"}"#)])
    await #expect(throws: NotionError.self) {
        try await NotionSetup.publishGuide(client: NotionClient(token: "s", transport: t), root: "root", title: "Hướng dẫn cho thầy", text: "x")
    }
    #expect(!t.requests.contains { $0.httpMethod == "PATCH" })     // nothing archived
}

@Test func missingGuideIsRecreatedButAPresentOneIsLeftAlone() async throws {
    let present = FakeTransport([children([("g", "Hướng dẫn cho thầy")])])
    #expect(try await NotionSetup.ensureGuide(client: NotionClient(token: "s", transport: present), root: "root", title: "Hướng dẫn cho thầy", text: { "x" }) == false)
    #expect(present.requests.count == 1)
    let missing = FakeTransport([children([("i", "Hộp thư")]), (200, #"{"id":"g"}"#)])
    #expect(try await NotionSetup.ensureGuide(client: NotionClient(token: "s", transport: missing), root: "root", title: "Hướng dẫn cho thầy", text: { "x" }) == true)
}

@Test func busyNotionIsRetried() async throws {
    let t = FakeTransport([(429, #"{"message":"rate limited"}"#), (200, #"{"id":"p"}"#)])
    let id = try await NotionClient(token: "s", transport: t, retryDelay: 0).createChildPage(parent: "x", title: "t")
    #expect(id == "p")
    #expect(t.requests.count == 2)
}

@Test func connectUsesTheTopSharedPageWhateverItsName() async throws {
    // "Drum" is shared; its subpages from an earlier connect show up in search too and must not be picked.
    let t = FakeTransport([
        searchResponse([("inbox", "Hộp thư"), ("drum", "Drum"), ("plans", "Kế hoạch")], parents: ["inbox": "drum", "plans": "drum"]),
        children([("inbox", "Hộp thư"), ("plans", "Kế hoạch"), ("ex", "Bài tập mới")]),
    ])
    let ws = try await NotionSetup.connect(client: NotionClient(token: "s", transport: t), titles: titles)
    #expect(ws == NotionWorkspace(root: "drum", rootTitle: "Drum", inbox: "inbox", plans: "plans", exercises: "ex"))
}
