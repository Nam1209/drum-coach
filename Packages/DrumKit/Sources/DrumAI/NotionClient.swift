import Foundation

/// Minimal Notion REST client (internal integration token): create a page with code blocks, list child pages, read code blocks.
public struct NotionClient: Sendable {
    public static let version = "2022-06-28"
    static let maxRichText = 2000
    static let maxRichTextPerBlock = 100

    let token: String
    let transport: HTTPTransport
    let base = URL(string: "https://api.notion.com/v1/")!

    public init(token: String, transport: HTTPTransport = URLSessionTransport()) {
        self.token = token
        self.transport = transport
    }

    /// Creates a child page; when `codeBlockJSON` is given it is stored in code blocks (split into ≤ 2000-char pieces).
    public func createChildPage(parent: String, title: String, codeBlockJSON: String? = nil) async throws -> String {
        var children: [JSONValue] = []
        if let text = codeBlockJSON {
            let pieces = Self.chunks(text, size: Self.maxRichText)
            for group in stride(from: 0, to: pieces.count, by: Self.maxRichTextPerBlock) {
                let rich = pieces[group..<min(group + Self.maxRichTextPerBlock, pieces.count)].map {
                    JSONValue.object(["type": .string("text"), "text": .object(["content": .string($0)])])
                }
                children.append(.object(["object": .string("block"), "type": .string("code"),
                                          "code": .object(["language": .string("json"), "rich_text": .array(Array(rich))])]))
            }
        }
        let body: JSONValue = .object([
            "parent": .object(["page_id": .string(parent)]),
            "properties": .object(["title": .object(["title": .array([.object(["text": .object(["content": .string(title)])])])])]),
            "children": .array(children),
        ])
        let json = try await request("pages", method: "POST", body: body)
        guard let id = json["id"] as? String else { throw NotionError.badResponse }
        return id
    }

    public func childPages(of parent: String) async throws -> [(id: String, title: String, created: Date)] {
        try await children(of: parent).compactMap { b in
            guard b["type"] as? String == "child_page", let id = b["id"] as? String else { return nil }
            let title = (b["child_page"] as? [String: Any])?["title"] as? String ?? ""
            let created = (b["created_time"] as? String).flatMap(Self.parseDate) ?? .distantPast
            return (id, title, created)
        }
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
        let (data, resp) = try await transport.send(req)
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
}
