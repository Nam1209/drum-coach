import DrumAnalysis
import Foundation

/// Free-form questions to the teacher over the API ("Tại sao tôi hay trễ ở &?"), with the student's history as context.
public struct TeacherChat: Sendable {
    let client: ClaudeClient
    let system: String
    public private(set) var history: [(role: String, text: String)] = []
    static let maxMessages = 21

    public init(client: ClaudeClient, digest: HistoryDigest, profile: StudentProfile, lastReport: TeacherReport?) {
        self.client = client
        struct Context: Encodable { let digest: HistoryDigest; let profile: StudentProfile; let lastReport: TeacherReport? }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = .sortedKeys
        let ctx = (try? enc.encode(Context(digest: digest, profile: profile, lastReport: lastReport))).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        system = """
        Bạn là thầy dạy trống 1-1 của học viên tự học, mục tiêu Rockschool Grade 8. Trả lời tiếng Việt, ngắn gọn, cụ thể,
        dựa trên dữ liệu tập luyện dưới đây (lệch ms: âm = sớm, dương = muộn). Có thể dùng web search khi cần tài liệu.
        Dữ liệu học viên (JSON): \(ctx)
        """
    }

    public mutating func ask(_ question: String) async throws(ClaudeError) -> String {
        history.append((role: "user", text: question))
        if history.count > Self.maxMessages { history.removeFirst(history.count - Self.maxMessages) }
        if history.first?.role == "assistant" { history.removeFirst() }
        do {
            let answer = try await client.text(system: system, messages: history, effort: .low, webSearch: true, maxTokens: 4000)
            history.append((role: "assistant", text: answer))
            return answer
        } catch {
            history.removeLast()
            throw error
        }
    }
}

/// Text for the daily practice reminder.
public enum ReminderContent {
    public static func daily(_ plan: DayPlan?) -> (title: String, body: String) {
        guard let plan, !plan.allItems.isEmpty else {
            return ("Đến giờ tập trống 🥁", "Khởi động single stroke 5 phút rồi làm bài test level tiếp theo nhé.")
        }
        let minutes = plan.allItems.reduce(0) { $0 + $1.minutes }
        let focus = plan.main.map(\.focus).prefix(2).joined(separator: ", ")
        return ("Hôm nay tập gì 🥁", "Hôm nay: \(focus.isEmpty ? "theo kế hoạch của thầy" : focus) — \(minutes) phút")
    }

    public static let weekly = (title: "Buổi gặp thầy hằng tuần", body: "Gửi báo cáo tuần cho thầy AI để nhận kế hoạch tuần mới.")
}
