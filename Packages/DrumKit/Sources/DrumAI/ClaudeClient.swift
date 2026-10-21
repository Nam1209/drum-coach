import Foundation

public protocol HTTPTransport: Sendable {
    func send(_ req: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}
    public func send(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

/// Minimal JSON value for writing schemas and request bodies.
public indirect enum JSONValue: Sendable, Equatable, Encodable {
    case string(String), number(Double), bool(Bool), null
    case array([JSONValue]), object([String: JSONValue])

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

public enum ContentBlock: Sendable {
    case text(String)
    case imagePNG(Data)

    var json: JSONValue {
        switch self {
        case .text(let t): .object(["type": .string("text"), "text": .string(t)])
        case .imagePNG(let d): .object(["type": .string("image"), "source": .object([
            "type": .string("base64"), "media_type": .string("image/png"), "data": .string(d.base64EncodedString())])])
        }
    }
}

public enum ClaudeError: Error, Equatable, Sendable {
    case missingKey
    case http(Int, String)
    case refused(String?)
    case decoding(String)
    case network(String)
}

public enum Effort: String, Sendable { case low, medium, high }

/// Claude Messages API over plain HTTP (Swift has no official SDK). Used only when the user enters an API key;
/// otherwise the app talks to Claude through the Pro subscription via Notion (Task 13B).
public struct ClaudeClient: Sendable {
    public static let defaultModel = "claude-opus-5-5"
    let apiKey: String
    let model: String
    let transport: HTTPTransport
    let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(apiKey: String, model: String = ClaudeClient.defaultModel, transport: HTTPTransport = URLSessionTransport()) {
        self.apiKey = apiKey
        self.model = model
        self.transport = transport
    }

    /// One request whose final text is JSON matching `schema` (structured outputs), decoded as `T`.
    public func structured<T: Decodable & Sendable>(system: String, content: [ContentBlock], schema: JSONValue, as: T.Type,
                                                    effort: Effort, webSearch: Bool, maxTokens: Int) async throws(ClaudeError) -> T {
        guard !apiKey.isEmpty else { throw .missingKey }
        var messages: [JSONValue] = [.object(["role": .string("user"), "content": .array(content.map(\.json))])]
        // Server tools may pause a long turn; continue it a few times.
        for _ in 0..<4 {
            let reply = try await send(system: system, messages: messages, schema: schema, effort: effort, webSearch: webSearch, maxTokens: maxTokens)
            switch reply.stopReason {
            case "refusal":
                throw .refused(reply.refusalExplanation)
            case "pause_turn":
                messages.append(.object(["role": .string("assistant"), "content": reply.rawContent]))
                continue
            default:
                guard let text = reply.lastText else { throw .decoding("Không có nội dung trả về") }
                do { return try JSONDecoder().decode(T.self, from: Data(text.utf8)) } catch { throw .decoding(String(describing: error)) }
            }
        }
        throw .decoding("Claude chưa trả lời xong")
    }

    /// Plain-text conversation turn (teacher chat).
    public func text(system: String, messages: [(role: String, text: String)], effort: Effort, webSearch: Bool,
                     maxTokens: Int) async throws(ClaudeError) -> String {
        guard !apiKey.isEmpty else { throw .missingKey }
        var msgs: [JSONValue] = messages.map { .object(["role": .string($0.role), "content": .string($0.text)]) }
        for _ in 0..<4 {
            let reply = try await send(system: system, messages: msgs, schema: nil, effort: effort, webSearch: webSearch, maxTokens: maxTokens)
            switch reply.stopReason {
            case "refusal": throw .refused(reply.refusalExplanation)
            case "pause_turn": msgs.append(.object(["role": .string("assistant"), "content": reply.rawContent])); continue
            default:
                guard let t = reply.allText, !t.isEmpty else { throw .decoding("Không có nội dung trả về") }
                return t
            }
        }
        throw .decoding("Claude chưa trả lời xong")
    }

    private struct Reply {
        let stopReason: String?
        let lastText: String?
        let allText: String?
        let rawContent: JSONValue
        let refusalExplanation: String?
    }

    private func send(system: String, messages: [JSONValue], schema: JSONValue?, effort: Effort,
                      webSearch: Bool, maxTokens: Int) async throws(ClaudeError) -> Reply {
        var body: [String: JSONValue] = [
            "model": .string(model),
            "max_tokens": .number(Double(maxTokens)),
            "system": .string(system),
            "messages": .array(messages),
            "thinking": .object(["type": .string("adaptive")]),
            "output_config": schema.map { .object(["effort": .string(effort.rawValue),
                                                   "format": .object(["type": .string("json_schema"), "schema": $0])]) }
                ?? .object(["effort": .string(effort.rawValue)]),
            "fallbacks": .string("default"),
        ]
        if webSearch {
            body["tools"] = .array([.object(["type": .string("web_search_20260209"), "name": .string("web_search"), "max_uses": .number(5)])])
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        req.httpBody = try? JSONEncoder().encode(JSONValue.object(body))

        let data: Data, resp: HTTPURLResponse
        do { (data, resp) = try await transport.send(req) } catch { throw .network(error.localizedDescription) }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(resp.statusCode) else {
            let msg = ((json["error"] as? [String: Any])?["message"] as? String) ?? String(data: data, encoding: .utf8) ?? ""
            throw .http(resp.statusCode, msg)
        }
        let content = json["content"] as? [[String: Any]] ?? []
        let texts = content.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }
        let lastText = texts.last
        let raw = (try? JSONSerialization.data(withJSONObject: content)).flatMap { try? JSONDecoder().decode(AnyJSON.self, from: $0) }
        return Reply(stopReason: json["stop_reason"] as? String, lastText: lastText, allText: texts.isEmpty ? nil : texts.joined(),
                     rawContent: raw?.value ?? .array([]),
                     refusalExplanation: (json["stop_details"] as? [String: Any])?["explanation"] as? String)
    }
}

/// Decodes arbitrary JSON into `JSONValue` (to echo assistant content back on pause_turn).
struct AnyJSON: Decodable {
    let value: JSONValue
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = .null }
        else if let b = try? c.decode(Bool.self) { value = .bool(b) }
        else if let n = try? c.decode(Double.self) { value = .number(n) }
        else if let s = try? c.decode(String.self) { value = .string(s) }
        else if let a = try? c.decode([AnyJSON].self) { value = .array(a.map(\.value)) }
        else { value = .object(try c.decode([String: AnyJSON].self).mapValues(\.value)) }
    }
}
