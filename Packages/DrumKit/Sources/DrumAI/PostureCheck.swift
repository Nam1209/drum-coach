import DrumCore
import Foundation

/// Grip and posture self-check from camera frames (the teacher can't see you, so the camera does).
public enum PostureCheck {
    public static var checklist: [String] { [
        L("Điểm tựa ở khoảng 1/3 dùi tính từ đuôi", "Fulcrum about 1/3 up the stick from the butt"),
        L("Kẹp dùi giữa ngón cái và đốt giữa ngón trỏ", "Stick held between the thumb and the middle joint of the index finger"),
        L("Ba ngón còn lại ôm nhẹ, lòng bàn tay có khoảng hở", "Other three fingers wrap loosely, a gap in the palm"),
        L("Mu bàn tay nghiêng khoảng 45° (American grip)", "Back of the hand tilted about 45° (American grip)"),
        L("Hai dùi tạo hình chữ V 60–90°", "Sticks form a 60–90° V"),
        L("Hai tay cầm giống nhau", "Both hands grip the same way"),
        L("Vai thả lỏng, không nhô lên", "Shoulders relaxed, not raised"),
        L("Khuỷu tay buông gần thân", "Elbows hang close to the body"),
        L("Cẳng tay gần song song mặt pad", "Forearms roughly parallel to the pad"),
        L("Lưng thẳng, không gồng", "Back straight but not stiff"),
        L("Dùi nảy lại tự nhiên, không ấn xuống", "Sticks rebound freely, not pressed into the head"),
    ] }

    /// `count` timestamps spread evenly over the take, skipping the count-in.
    public static func pickFrames(count: Int, duration: TimeInterval, avoidFirst: TimeInterval) -> [TimeInterval] {
        guard count > 0, duration > avoidFirst else { return [] }
        let span = duration - avoidFirst
        return (0..<count).map { avoidFirst + span * (Double($0) + 0.5) / Double(count) }
    }

    public static func prompt(exercise: String, date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let list = checklist.map { "- " + $0 }.joined(separator: "\n")
        return L("""
        Thầy ơi, đây là ảnh em tập "\(exercise)" ngày \(f.string(from: date)). Nhờ thầy nhận xét cách cầm dùi và tư thế theo checklist:
        \(list)
        Nói rõ điều em làm tốt, tối đa 3 điều cần sửa, và một bài tập ngắn để sửa.
        """, """
        Hi teacher, these are photos of me practising "\(exercise)" on \(f.string(from: date)). Please review my grip and posture against this checklist:
        \(list)
        Tell me what I do well, at most 3 things to fix, and one short drill to fix them.
        """)
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
        try await client.structured(system: L("Bạn là giáo viên trống, nhận xét tư thế và cách cầm dùi từ ảnh. Tiếng Việt, cụ thể, nhẹ nhàng. Chỉ nói điều thấy được trong ảnh.", "You are a drum teacher reviewing grip and posture from photos. Answer in English, concretely and kindly. Only comment on what is visible."),
                                    content: frames.map(ContentBlock.imageJPEG) + [.text(prompt(exercise: exercise, date: Date()))],
                                    schema: schema, as: Review.self, effort: .medium, webSearch: false, maxTokens: 4000)
    }
}
