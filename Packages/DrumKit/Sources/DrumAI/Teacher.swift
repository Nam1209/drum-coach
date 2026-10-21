import DrumAnalysis
import Foundation

/// The AI teacher over the Claude API (used only when the user entered an API key; otherwise the Notion bridge is used).
public enum Teacher {
    static let systemPrompt = """
    Bạn là thầy dạy trống 1-1 của học viên tự học (không có thầy thật), mục tiêu Rockschool Grade 8. Nói tiếng Việt, cụ thể, nhẹ nhàng.
    Thang điểm Rockschool: Pass 60%, Merit 74%, Distinction 90%. Dữ liệu là số đo thật (score %, lệch ms: âm = sớm, dương = muộn).
    Chỉ dựa trên số liệu. Nhắc lại lời khuyên cũ (profile.pastAdvice) và đánh giá học viên đã làm theo chưa.
    Tối đa 3 điều cần sửa, theo ưu tiên. Kế hoạch 7 ngày, mỗi ngày khoảng profile.minutesPerDay phút; ưu tiên bài trong thư viện (exerciseId),
    thiếu thì viết bài mới bằng DSL (newExerciseDSL). Dùng web search tìm 2–4 video/bài viết uy tín cho đúng điểm yếu; mỗi tài liệu có searchQuery.

    Định dạng DSL: các dòng "title:", "time: 4/4", "tempo: 60-100", "grid: 4" rồi các dòng voice (HH OH HP SN SS BD T1 T2 FT RD CR) và "ST:" sticking,
    mỗi ký tự một ô: x đánh, X accent, g ghost, f flam, d drag, z buzz, - nghỉ. Mọi dòng dài bằng nhau, đủ trọn ô nhịp.
    """

    static let schema: JSONValue = {
        let str: JSONValue = .object(["type": .string("string")])
        let strs: JSONValue = .object(["type": .string("array"), "items": str])
        let int: JSONValue = .object(["type": .string("integer")])
        let nullableStr: JSONValue = .object(["type": .array([.string("string"), .string("null")])])
        let item: JSONValue = .object(["type": .string("object"), "additionalProperties": .bool(false),
                                       "properties": .object(["exerciseId": nullableStr, "newExerciseDSL": nullableStr, "bpm": int, "minutes": int, "focus": str]),
                                       "required": .array(["exerciseId", "newExerciseDSL", "bpm", "minutes", "focus"].map(JSONValue.string))])
        let items: JSONValue = .object(["type": .string("array"), "items": item])
        let day: JSONValue = .object(["type": .string("object"), "additionalProperties": .bool(false),
                                      "properties": .object(["day": int, "warmup": items, "main": items, "fun": items]),
                                      "required": .array(["day", "warmup", "main", "fun"].map(JSONValue.string))])
        let resource: JSONValue = .object(["type": .string("object"), "additionalProperties": .bool(false),
                                           "properties": .object(["kind": str, "title": str, "url": nullableStr, "why": str, "searchQuery": str]),
                                           "required": .array(["kind", "title", "url", "why", "searchQuery"].map(JSONValue.string))])
        return .object(["type": .string("object"), "additionalProperties": .bool(false),
                        "properties": .object(["summary": str, "progress": strs, "fixFirst": strs, "likelyCauses": strs,
                                               "weekPlan": .object(["type": .string("array"), "items": day]),
                                               "resources": .object(["type": .string("array"), "items": resource]), "nextCheckpoint": str]),
                        "required": .array(["summary", "progress", "fixFirst", "likelyCauses", "weekPlan", "resources", "nextCheckpoint"].map(JSONValue.string))])
    }()

    public static func weeklyReport(digest: HistoryDigest, profile: StudentProfile, library: [String: String],
                                    client: ClaudeClient) async throws(ClaudeError) -> TeacherReport {
        struct Context: Encodable { let digest: HistoryDigest; let profile: StudentProfile; let library: [String: String] }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = .sortedKeys
        let text = (try? enc.encode(Context(digest: digest, profile: profile, library: library))).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return try await client.structured(system: systemPrompt, content: [.text("Dữ liệu học viên (JSON):\n\(text)")], schema: schema,
                                           as: TeacherReport.self, effort: .high, webSearch: true, maxTokens: 32_000)
    }

    /// Rough USD estimate for one weekly report on Claude Opus 5.5 ($4 / $20 per million tokens), excluding web-search fees.
    public static func estimatedCostUSD(inputBytes: Int) -> Double {
        let inputTokens = Double(inputBytes) / 3 + 3_000 + 20_000   // data + instructions + search results
        let outputTokens = 8_000.0
        return inputTokens * 4 / 1_000_000 + outputTokens * 20 / 1_000_000
    }
}
