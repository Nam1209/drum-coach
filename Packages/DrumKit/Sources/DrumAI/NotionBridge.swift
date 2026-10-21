import DrumCore
import Foundation

public enum BridgeError: Error, Equatable, Sendable {
    case noJSONBlock
    case invalidJSON(String)
    case schemaMismatch(String)
}

/// Talks to the AI teacher through Notion: the app writes reports to "Hộp thư", Claude (Pro, in a Project with the
/// Notion connector) writes plans to "Kế hoạch" and new exercises to "Bài tập mới"; the app syncs them back.
public struct NotionBridge: Sendable {
    public enum Kind: String, Sendable {
        case weekly, period, posture, backup

        /// Page-title prefix in the app language.
        public var title: String {
            switch self {
            case .weekly: L("Báo cáo", "Report")
            case .period: L("Tổng kết", "Review")
            case .posture: L("Tư thế", "Posture")
            case .backup: "Backup"
            }
        }
    }

    let client: NotionClient
    let inboxPageId: String
    let plansPageId: String
    let exercisesPageId: String?

    public init(client: NotionClient, inboxPageId: String, plansPageId: String, exercisesPageId: String? = nil) {
        self.client = client
        self.inboxPageId = inboxPageId
        self.plansPageId = plansPageId
        self.exercisesPageId = exercisesPageId
    }

    public static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// Uploads a report page; returns its title and the short message to paste into the Claude Project.
    public func send<Payload: Encodable & Sendable>(kind: Kind, payload: Payload, profile: StudentProfile, date: Date) async throws -> (pageTitle: String, prompt: String) {
        let day = Self.dayString(date)
        let title = "\(kind.title) \(day)"
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let json = String(data: try enc.encode(Envelope(kind: kind.rawValue, date: day, profile: profile, data: payload)), encoding: .utf8) ?? "{}"
        // One page per kind per day: sending again that day updates it (each report already holds everything).
        if let existing = try await client.childPages(of: inboxPageId).first(where: { $0.title == title }) {
            try await client.replaceContent(page: existing.id, codeBlockJSON: json)
        } else {
            _ = try await client.createChildPage(parent: inboxPageId, title: title, codeBlockJSON: json)
        }
        let ask: String
        switch kind {
        case .weekly: ask = L("Thầy ơi, xem \(title) trong Hộp thư và viết Kế hoạch \(day) giúp em.", "Hi teacher, please read \(title) in the Inbox and write Plan \(day) for me.")
        case .period: ask = L("Thầy ơi, xem \(title) trong Hộp thư và tổng kết giai đoạn, đặt mục tiêu 3 tháng tới (ghi vào Kế hoạch \(day)).", "Hi teacher, please read \(title) in the Inbox, review this period and set goals for the next 3 months (write them in Plan \(day)).")
        case .posture: ask = L("Thầy ơi, xem \(title) trong Hộp thư và nhận xét cách cầm dùi, tư thế của em.", "Hi teacher, please read \(title) in the Inbox and review my grip and posture.")
        case .backup: ask = ""
        }
        return (title, ask)
    }

    /// Plan pages not yet imported (tracked by page id, so pages created in the same minute and pages that failed
    /// earlier — e.g. Claude was still writing — are fetched again).
    public func fetchPlans(excluding imported: Set<String>) async throws -> [(pageId: String, title: String, created: Date, report: Result<TeacherReport, BridgeError>)] {
        var out: [(pageId: String, title: String, created: Date, report: Result<TeacherReport, BridgeError>)] = []
        for p in try await client.childPages(of: plansPageId).filter({ !imported.contains($0.id) }).sorted(by: { $0.created < $1.created }) {
            out.append((p.id, p.title, p.created, Self.decodeReport(try await client.codeBlocks(of: p.id))))
        }
        return out
    }

    public struct PlanPage: Sendable {
        public let pageId: String
        public let title: String
        public let created: Date
        /// Identifies the page's JSON; store it and pass it back in `seen` to notice later edits.
        public let fingerprint: String
        /// The page was imported before and Claude has since rewritten it.
        public let isRevision: Bool
        public let report: Result<TeacherReport, BridgeError>
    }

    /// New plan pages, plus pages imported before whose JSON has changed (Claude often rewrites the same day's page).
    /// `seen` maps imported page ids to their fingerprint; only those created since `recheckSince` are re-read.
    public func fetchPlans(seen: [String: String], recheckSince: Date) async throws -> [PlanPage] {
        var out: [PlanPage] = []
        for p in try await client.childPages(of: plansPageId).sorted(by: { $0.created < $1.created }) {
            let known = seen[p.id]
            if known != nil, p.created < recheckSince { continue }
            let blocks = try await client.codeBlocks(of: p.id)
            let print = Self.fingerprint(blocks)
            guard print != known else { continue }
            out.append(PlanPage(pageId: p.id, title: p.title, created: p.created, fingerprint: print,
                                isRevision: known != nil, report: Self.decodeReport(blocks)))
        }
        return out
    }

    /// FNV-1a over the page's code blocks: stable across launches (unlike `hashValue`).
    static func fingerprint(_ blocks: [String]) -> String {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in blocks.joined(separator: "\u{1F}").utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01b3 }
        return String(h, radix: 16)
    }

    /// DSL exercises Claude wrote (e.g. transcribed from the user's book) per page, skipping anything that does not parse.
    /// Pages with no valid exercise yet are returned with an empty list so the caller can retry them later.
    public func fetchExercisePages(excluding imported: Set<String>) async throws -> [(pageId: String, dsl: [String])] {
        guard let exercisesPageId else { return [] }
        var out: [(pageId: String, dsl: [String])] = []
        for p in try await client.childPages(of: exercisesPageId) where !imported.contains(p.id) {
            var dsl: [String] = []
            for block in try await client.codeBlocks(of: p.id) {
                let parts = block.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                dsl += parts.filter { !$0.isEmpty && (try? ExerciseDSL.parse($0)) != nil }
            }
            out.append((p.id, dsl))
        }
        return out
    }

    struct Envelope<P: Encodable>: Encodable {
        let kind: String
        let date: String
        let profile: StudentProfile
        let data: P
    }

    static func decodeReport(_ blocks: [String]) -> Result<TeacherReport, BridgeError> {
        guard !blocks.isEmpty else { return .failure(.noJSONBlock) }
        var lastError = BridgeError.noJSONBlock
        for text in blocks.reversed() {
            let data = Data(text.utf8)
            guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
                lastError = .invalidJSON(String(text.prefix(80)))
                continue
            }
            do { return .success(try JSONDecoder().decode(TeacherReport.self, from: data)) }
            catch { lastError = .schemaMismatch(String(describing: error).prefix(200).description) }
        }
        return .failure(lastError)
    }
}
