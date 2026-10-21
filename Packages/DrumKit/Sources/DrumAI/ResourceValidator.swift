import Foundation

/// Makes sure every suggested link is real: YouTube links are checked with oEmbed, other links with HEAD.
/// Dead or missing links become a search link for the resource's `searchQuery`, so nothing points nowhere.
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
        guard let url = r.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return search(r, youtube: isYouTube) }
        if isYouTube || url.host?.contains("youtube.com") == true || url.host == "youtu.be" {
            let enc = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            guard let oembed = URL(string: "https://www.youtube.com/oembed?url=\(enc)&format=json") else { return search(r, youtube: true) }
            return await status(URLRequest(url: oembed)) == 200 ? url : search(r, youtube: true)
        }
        var head = URLRequest(url: url)
        head.httpMethod = "HEAD"
        let code = await status(head)
        return (200..<400).contains(code) ? url : search(r, youtube: false)
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
