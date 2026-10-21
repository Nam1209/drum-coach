import Foundation

/// Minimal Notion REST client (internal integration token): create a page with code blocks, list child pages, read code blocks.
public struct NotionClient: Sendable {
    public static let version = "2022-06-28"
    static let maxRichText = 2000
    static let maxRichTextPerBlock = 100

    let token: String
    let transport: HTTPTransport
    let base = URL(string: "https://api.notion.com/v1/")!

    /// Seconds to wait before retrying when Notion says it is busy (429); doubles on each retry.
    let retryDelay: TimeInterval

    public init(token: String, transport: HTTPTransport = URLSessionTransport(), retryDelay: TimeInterval = 1) {
        self.token = token
        self.transport = transport
        self.retryDelay = retryDelay
    }

    /// Notion rejects request bodies above ~500 KB; one full code block is ~200 KB, so at most 2 blocks per request.
    static let blocksPerRequest = 2

    /// Creates a child page; when `codeBlockJSON` is given it is stored in code blocks (≤ 2000-char pieces, ≤ 100 per block),
    /// sent in several requests (create, then append) so large backups stay under Notion's size limit.
    public func createChildPage(parent: String, title: String, codeBlockJSON: String? = nil, codeLanguage: String = "json") async throws -> String {
        let blocks = codeBlockJSON.map { Self.codeBlocks($0, language: codeLanguage) } ?? []
        let first = Array(blocks.prefix(Self.blocksPerRequest))
        let body: JSONValue = .object([
            "parent": .object(["page_id": .string(parent)]),
            "properties": .object(["title": .object(["title": .array([.object(["text": .object(["content": .string(title)])])])])]),
            "children": .array(first),
        ])
        let json = try await request("pages", method: "POST", body: body)
        guard let id = json["id"] as? String else { throw NotionError.badResponse }
        try await append(Array(blocks.dropFirst(Self.blocksPerRequest)), to: id)
        return id
    }

    /// Replaces everything on a page with new code blocks (the old blocks go to Notion's trash).
    public func replaceContent(page: String, codeBlockJSON: String, codeLanguage: String = "json") async throws {
        for block in try await children(of: page) {
            guard let id = block["id"] as? String else { continue }
            _ = try await request("blocks/\(id)", method: "DELETE", body: nil)
        }
        try await append(Self.codeBlocks(codeBlockJSON, language: codeLanguage), to: page)
    }

    /// Text stored in code blocks: ≤ 2000-char pieces, ≤ 100 pieces per block.
    static func codeBlocks(_ text: String, language: String) -> [JSONValue] {
        let pieces = chunks(text, size: maxRichText)
        return stride(from: 0, to: pieces.count, by: maxRichTextPerBlock).map { group in
            let rich = pieces[group..<min(group + maxRichTextPerBlock, pieces.count)].map {
                JSONValue.object(["type": .string("text"), "text": .object(["content": .string($0)])])
            }
            return .object(["object": .string("block"), "type": .string("code"),
                            "code": .object(["language": .string(language), "rich_text": .array(Array(rich))])])
        }
    }

    /// Appends blocks a few at a time so large backups stay under Notion's request size limit.
    private func append(_ blocks: [JSONValue], to page: String) async throws {
        var rest = blocks[...]
        while !rest.isEmpty {
            let batch = Array(rest.prefix(Self.blocksPerRequest))
            rest = rest.dropFirst(Self.blocksPerRequest)
            _ = try await request("blocks/\(page)/children", method: "PATCH", body: .object(["children": .array(batch)]))
        }
    }

    public func childPages(of parent: String) async throws -> [(id: String, title: String, created: Date)] {
        try await children(of: parent).compactMap { b in
            guard b["type"] as? String == "child_page", let id = b["id"] as? String else { return nil }
            let title = (b["child_page"] as? [String: Any])?["title"] as? String ?? ""
            let created = (b["created_time"] as? String).flatMap(Self.parseDate) ?? .distantPast
            return (id, title, created)
        }
    }

    /// Pages this integration has been given access to, matching `query` (Notion's own title search).
    public func searchPages(_ query: String = "") async throws -> [(id: String, title: String, parentPage: String?)] {
        let json = try await request("search", method: "POST", body: .object([
            "query": .string(query),
            "filter": .object(["property": .string("object"), "value": .string("page")]),
        ]))
        return (json["results"] as? [[String: Any]] ?? []).compactMap { page in
            guard let id = page["id"] as? String else { return nil }
            let props = page["properties"] as? [String: Any] ?? [:]
            let titleProp = props.values.compactMap { $0 as? [String: Any] }.first { $0["type"] as? String == "title" }
            let title = (titleProp?["title"] as? [[String: Any]] ?? []).compactMap { $0["plain_text"] as? String }.joined()
            return (id, title, (page["parent"] as? [String: Any])?["page_id"] as? String)
        }
    }

    /// Moves a page to Notion's trash (recoverable there for 30 days).
    public func archive(page: String) async throws {
        _ = try await request("pages/\(page)", method: "PATCH", body: .object(["archived": .bool(true)]))
    }

    /// Text of every code block on the page (rich-text pieces joined).
    public func codeBlocks(of page: String) async throws -> [String] {
        try await children(of: page).compactMap { b in
            guard b["type"] as? String == "code", let code = b["code"] as? [String: Any],
                  let rich = code["rich_text"] as? [[String: Any]] else { return nil }
            return rich.map { ($0["plain_text"] as? String) ?? (($0["text"] as? [String: Any])?["content"] as? String) ?? "" }.joined()
        }
    }

    private func children(of id: String) async throws -> [[String: Any]] {
        var out: [[String: Any]] = []
        var cursor: String?
        repeat {
            let path = "blocks/\(id)/children?page_size=100" + (cursor.map { "&start_cursor=\($0)" } ?? "")
            let json = try await request(path, method: "GET", body: nil)
            out += json["results"] as? [[String: Any]] ?? []
            cursor = (json["has_more"] as? Bool) == true ? json["next_cursor"] as? String : nil
        } while cursor != nil
        return out
    }

    private func request(_ path: String, method: String, body: JSONValue?) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: path, relativeTo: base)!.absoluteURL)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(Self.version, forHTTPHeaderField: "Notion-Version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = try JSONEncoder().encode(body) }
        var (data, resp) = try await transport.send(req)
        // Notion allows about 3 requests a second; a big backup can hit that, so wait and try again.
        var wait = retryDelay
        for _ in 0..<4 where resp.statusCode == 429 {
            let hinted = resp.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
            try await Task.sleep(for: .seconds(max(wait, retryDelay > 0 ? hinted ?? 0 : 0)))
            wait *= 2
            (data, resp) = try await transport.send(req)
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(resp.statusCode) else {
            throw NotionError.http(resp.statusCode, json["message"] as? String ?? "")
        }
        return json
    }

    /// The 32-hex page id inside a Notion link (or an id pasted directly), formatted as a UUID.
    public static func pageId(fromLink link: String) -> String? {
        let hex = link.lowercased().replacingOccurrences(of: "-", with: "")
        guard let range = hex.range(of: "[0-9a-f]{32}", options: .regularExpression) else { return nil }
        let h = Array(hex[range])
        return [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { String(h[$0]) }.joined(separator: "-")
    }

    static func chunks(_ s: String, size: Int) -> [String] {
        var out: [String] = []
        var rest = Substring(s)
        while !rest.isEmpty {
            out.append(String(rest.prefix(size)))
            rest = rest.dropFirst(size)
        }
        return out
    }

    static func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}

public enum NotionError: Error, Equatable {
    case http(Int, String)
    case badResponse
    /// The token works but no page was shared with the integration.
    case noSharedPage
}
