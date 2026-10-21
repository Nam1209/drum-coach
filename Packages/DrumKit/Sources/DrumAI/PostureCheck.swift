import Foundation

/// Grip and posture self-check from camera frames (the teacher can't see you, so the camera does).
public enum PostureCheck {
    public static let checklist = [
        "Điểm tựa ở khoảng 1/3 dùi tính từ đuôi",
        "Kẹp dùi giữa ngón cái và đốt giữa ngón trỏ",
        "Ba ngón còn lại ôm nhẹ, lòng bàn tay có khoảng hở",
        "Mu bàn tay nghiêng khoảng 45° (American grip)",
        "Hai dùi tạo hình chữ V 60–90°",
        "Hai tay cầm giống nhau",
        "Vai thả lỏng, không nhô lên",
        "Khuỷu tay buông gần thân",
        "Cẳng tay gần song song mặt pad",
        "Lưng thẳng, không gồng",
        "Dùi nảy lại tự nhiên, không ấn xuống",
    ]

    /// `count` timestamps spread evenly over the take, skipping the count-in.
    public static func pickFrames(count: Int, duration: TimeInterval, avoidFirst: TimeInterval) -> [TimeInterval] {
        guard count > 0, duration > avoidFirst else { return [] }
        let span = duration - avoidFirst
        return (0..<count).map { avoidFirst + span * (Double($0) + 0.5) / Double(count) }
    }

    public static func prompt(exercise: String, date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return """
        Thầy ơi, đây là ảnh em tập "\(exercise)" ngày \(f.string(from: date)). Nhờ thầy nhận xét cách cầm dùi và tư thế theo checklist:
        \(checklist.map { "- " + $0 }.joined(separator: "\n"))
        Nói rõ điều em làm tốt, tối đa 3 điều cần sửa, và một bài tập ngắn để sửa.
        """
    }

    public struct Review: Codable, Sendable, Equatable {
        public let good: [String]
        public let fix: [String]
        public let drill: String
    }

    static let schema: JSONValue = .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "properties": .object(["good": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
                               "fix": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
                               "drill": .object(["type": .string("string")])]),
        "required": .array(["good", "fix", "drill"].map(JSONValue.string)),
    ])

    /// API path: Claude looks at JPEG frames and answers against the checklist.
    public static func review(frames: [Data], exercise: String, client: ClaudeClient) async throws(ClaudeError) -> Review {
        try await client.structured(system: "Bạn là giáo viên trống, nhận xét tư thế và cách cầm dùi từ ảnh. Tiếng Việt, cụ thể, nhẹ nhàng. Chỉ nói điều thấy được trong ảnh.",
                                    content: frames.map(ContentBlock.imageJPEG) + [.text(prompt(exercise: exercise, date: Date()))],
                                    schema: schema, as: Review.self, effort: .medium, webSearch: false, maxTokens: 4000)
    }
}
