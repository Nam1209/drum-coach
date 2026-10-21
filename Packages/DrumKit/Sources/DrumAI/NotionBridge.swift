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
        case weekly = "Báo cáo"
        case period = "Tổng kết"
        case posture = "Tư thế"
        case backup = "Backup"
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
        let title = "\(kind.rawValue) \(day)"
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let json = String(data: try enc.encode(Envelope(kind: kind.rawValue, date: day, profile: profile, data: payload)), encoding: .utf8) ?? "{}"
        _ = try await client.createChildPage(parent: inboxPageId, title: title, codeBlockJSON: json)
        let ask: String
        switch kind {
        case .weekly: ask = "Thầy ơi, xem \(title) trong Hộp thư và viết Kế hoạch \(day) giúp em."
        case .period: ask = "Thầy ơi, xem \(title) trong Hộp thư và tổng kết giai đoạn, đặt mục tiêu 3 tháng tới (ghi vào Kế hoạch \(day))."
        case .posture: ask = "Thầy ơi, xem \(title) trong Hộp thư và nhận xét cách cầm dùi, tư thế của em."
        case .backup: ask = ""
        }
        return (title, ask)
    }

    public func fetchNewPlans(after lastImported: Date?) async throws -> [(title: String, created: Date, report: Result<TeacherReport, BridgeError>)] {
        let pages = try await client.childPages(of: plansPageId)
            .filter { lastImported == nil || $0.created > lastImported! }
            .sorted { $0.created < $1.created }
        var out: [(title: String, created: Date, report: Result<TeacherReport, BridgeError>)] = []
        for p in pages {
            let blocks = try await client.codeBlocks(of: p.id)
            out.append((p.title, p.created, Self.decodeReport(blocks)))
        }
        return out
    }

    /// DSL exercises Claude wrote (e.g. transcribed from the user's book), skipping anything that does not parse.
    public func fetchNewExercises(after lastImported: Date?) async throws -> [String] {
        guard let exercisesPageId else { return [] }
        var out: [String] = []
        for p in try await client.childPages(of: exercisesPageId).filter({ lastImported == nil || $0.created > lastImported! }) {
            for block in try await client.codeBlocks(of: p.id) {
                let parts = block.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                out += parts.filter { !$0.isEmpty && (try? ExerciseDSL.parse($0)) != nil }
            }
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
