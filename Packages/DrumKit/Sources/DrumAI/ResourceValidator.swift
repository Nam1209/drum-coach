import Foundation

/// Makes sure every suggested link is usable. YouTube links are checked through YouTube's own oEmbed endpoint (the only
/// request this makes — plans can come from an editable Notion page, so arbitrary hosts are never contacted).
/// Other links are kept only if they are https to a public-looking host name. Anything else becomes a search link.
public struct ResourceValidator: Sendable {
    let transport: HTTPTransport

    public init(transport: HTTPTransport = URLSessionTransport()) { self.transport = transport }

    public func validate(_ resources: [Resource]) async -> [Resource] {
        var out: [Resource] = []
        for var r in resources {
            r.url = await checked(r)
            out.append(r)
        }
        return out
    }

    private func checked(_ r: Resource) async -> URL {
        let isYouTube = r.kind == "youtube"
        guard let url = r.url, url.scheme?.lowercased() == "https", let host = url.host?.lowercased(), Self.isPublicHostName(host) else {
            return search(r, youtube: isYouTube)
        }
        if Self.youTubeHosts.contains(host) {
            let enc = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            guard let oembed = URL(string: "https://www.youtube.com/oembed?url=\(enc)&format=json") else { return search(r, youtube: true) }
            return await status(URLRequest(url: oembed)) == 200 ? url : search(r, youtube: true)
        }
        // A "youtube" resource that is not on YouTube is not trusted as a video link.
        return isYouTube ? search(r, youtube: true) : url
    }

    static let youTubeHosts: Set<String> = ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"]

    /// Rejects IP literals, localhost, .local/.internal names and single-label hosts.
    static func isPublicHostName(_ host: String) -> Bool {
        let h = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if h.contains(":") { return false }                                       // IPv6 literal
        if h.split(separator: ".").allSatisfy({ Int($0) != nil }) { return false } // IPv4 literal
        if !h.contains(".") || h == "localhost" { return false }
        return ![".local", ".localhost", ".internal", ".lan", ".home", ".arpa"].contains { h.hasSuffix($0) }
    }

    private func status(_ req: URLRequest) async -> Int {
        var req = req
        req.timeoutInterval = 10
        return (try? await transport.send(req).1.statusCode) ?? 0
    }

    private func search(_ r: Resource, youtube: Bool) -> URL {
        let q = r.searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: youtube ? "https://www.youtube.com/results?search_query=\(q)" : "https://www.google.com/search?q=\(q)")!
    }
}
