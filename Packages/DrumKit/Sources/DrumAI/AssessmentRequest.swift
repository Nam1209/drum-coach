import DrumAnalysis
import Foundation

public struct AssessmentInput: Codable, Sendable {
    public let exerciseTitle: String
    public let skill: String
    /// Rockschool grade the exercise belongs to.
    public let grade: Int
    public let bpm: Double
    public let targetBpm: Int
    public let stats: SessionStats
    /// Up to 10 earlier runs of the same exercise.
    public let recentHistory: [SessionStats]
    public let mode: String

    public init(exerciseTitle: String, skill: String, grade: Int, bpm: Double, targetBpm: Int, stats: SessionStats,
                recentHistory: [SessionStats], mode: String) {
        self.exerciseTitle = exerciseTitle
        self.skill = skill
        self.grade = grade
        self.bpm = bpm
        self.targetBpm = targetBpm
        self.stats = stats
        self.recentHistory = Array(recentHistory.suffix(10))
        self.mode = mode
    }
}

public struct Assessment: Codable, Sendable, Equatable {
    public let estimatedGrade: Int
    /// "Below Pass" | "Pass" | "Merit" | "Distinction"
    public let band: String
    public let timingComment: String
    public let strengths: [String]
    public let weaknesses: [String]
    public let nextSteps: [String]
    public let suggestedTempo: Int
}

public enum AssessmentRequest {
    public static let systemPrompt = """
    Bạn là giám khảo và giáo viên trống theo chuẩn Rockschool (RSL), nói tiếng Việt, cụ thể và nhẹ nhàng.
    Học viên tự học, mục tiêu Rockschool Grade 8, chưa có thầy dạy trực tiếp.
    Thang điểm Rockschool: Pass 60%+, Merit 74%+, Distinction 90%+. Giám khảo nghe: độ chính xác nhịp, độ ổn định tempo,
    sắc thái (accent/ghost), sự trôi chảy và sticking.
    Dữ liệu là số đo thật từ app (score %, lệch trung bình ms: âm = sớm, dương = muộn, độ lệch chuẩn, lệch theo vị trí đếm và theo tay).
    Chỉ dựa trên số liệu, không bịa. Đưa tối đa 3 điểm yếu, ưu tiên cái ảnh hưởng nhiều nhất, và 3 bước tiếp theo cụ thể
    (bài gì, tempo bao nhiêu, tập bao lâu). estimatedGrade trong khoảng 1–8.
    """

    static let schema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "estimatedGrade": .object(["type": .string("integer")]),
            "band": .object(["type": .string("string"), "enum": .array(["Below Pass", "Pass", "Merit", "Distinction"].map(JSONValue.string))]),
            "timingComment": .object(["type": .string("string")]),
            "strengths": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
            "weaknesses": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
            "nextSteps": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
            "suggestedTempo": .object(["type": .string("integer")]),
        ]),
        "required": .array(["estimatedGrade", "band", "timingComment", "strengths", "weaknesses", "nextSteps", "suggestedTempo"].map(JSONValue.string)),
        "additionalProperties": .bool(false),
    ])

    public static func run(_ input: AssessmentInput, client: ClaudeClient) async throws(ClaudeError) -> Assessment {
        let data = (try? JSONEncoder().encode(input)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let a = try await client.structured(system: systemPrompt, content: [.text("Kết quả buổi tập:\n\(data)")],
                                            schema: schema, as: Assessment.self, effort: .medium, webSearch: false, maxTokens: 8000)
        return Assessment(estimatedGrade: min(8, max(1, a.estimatedGrade)), band: a.band, timingComment: a.timingComment,
                          strengths: a.strengths, weaknesses: a.weaknesses, nextSteps: a.nextSteps, suggestedTempo: a.suggestedTempo)
    }

    /// Try Claude when a client is available; otherwise (or on any error) use the local rules. Local results are never lost.
    public static func runOrFallback(_ input: AssessmentInput, client: ClaudeClient?) async -> (assessment: Assessment, usedAI: Bool, error: String?) {
        guard let client else { return (localFallback(input), false, nil) }
        do {
            return (try await run(input, client: client), true, nil)
        } catch {
            return (localFallback(input), false, "Không kết nối được Claude — đang dùng đánh giá cục bộ (\(error))")
        }
    }

    /// Rule-based assessment from the measured numbers.
    public static func localFallback(_ input: AssessmentInput) -> Assessment {
        let s = input.stats
        let atTempo = input.bpm >= Double(input.targetBpm) * 0.97
        let band: String
        if s.score >= 90, s.stdDevMs <= 20, atTempo { band = "Distinction" }
        else if s.score >= 74 { band = "Merit" }
        else if s.score >= 60 { band = "Pass" }
        else { band = "Below Pass" }
        let grade = min(8, max(1, band == "Below Pass" ? input.grade - 1 : input.grade))

        var strengths: [String] = [], weaknesses: [String] = [], steps: [String] = []
        if abs(s.meanOffsetMs) < 10 { strengths.append("Bám tempo tốt (lệch trung bình \(Int(s.meanOffsetMs.rounded())) ms).") }
        if s.stdDevMs < 15 { strengths.append("Nhịp đều (dao động ±\(Int(s.stdDevMs.rounded())) ms).") }
        if s.meanOffsetMs <= -10 { weaknesses.append("Hay đánh sớm \(Int((-s.meanOffsetMs).rounded())) ms.") }
        if s.meanOffsetMs >= 10 { weaknesses.append("Hay đánh muộn \(Int(s.meanOffsetMs.rounded())) ms.") }
        if s.stdDevMs >= 20 { weaknesses.append("Nhịp chưa đều (dao động ±\(Int(s.stdDevMs.rounded())) ms).") }
        if let (label, ms) = s.byBeatPosition.max(by: { abs($0.value) < abs($1.value) }), abs(ms) >= 15 {
            weaknesses.append("Vị trí \"\(label)\" lệch \(Int(ms.rounded())) ms.")
        }
        if s.missed > 0 { weaknesses.append("Trượt \(s.missed) nốt.") }

        let suggested: Int
        if s.score > 90, atTempo { suggested = Int(input.bpm) + 4; steps.append("Tăng tempo lên \(suggested) BPM.") }
        else if s.score >= 74 { suggested = Int(input.bpm); steps.append("Giữ \(suggested) BPM tới khi đạt trên 90%.") }
        else { suggested = max(40, Int(input.bpm) - 8); steps.append("Giảm về \(suggested) BPM, tập chậm cho sạch rồi tăng dần.") }
        steps.append("Bật giọng đếm và đếm to theo khi tập.")

        return Assessment(estimatedGrade: grade, band: band,
                          timingComment: String(format: "Score %.0f%%, lệch trung bình %+.0f ms, dao động ±%.0f ms.", s.score, s.meanOffsetMs, s.stdDevMs),
                          strengths: Array(strengths.prefix(3)), weaknesses: Array(weaknesses.prefix(3)), nextSteps: steps, suggestedTempo: suggested)
    }
}
