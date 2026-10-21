import DrumCore
import Foundation

/// Turns a photographed/rendered book page into exercise DSL (only for books the user owns; stays on device).
public enum PageTranscriber {
    public static var instructions: String { L("""
    Bạn chuyển các bài tập trống trên trang sách thành định dạng text sau. Mỗi bài một chuỗi riêng.

    title: <tên bài tiếng Việt, ví dụ "Stick Control tr.5 #1">
    title_en: <tên bài tiếng Anh, ví dụ "Stick Control p5 #1">
    time: 4/4            (số chỉ nhịp)
    tempo: 60-100        (khoảng tempo gợi ý; nếu sách ghi ♩=70 thì 70-70)
    grid: 4              (số ô trên một phách: 2 = móc đơn, 4 = móc kép, 3 = chùm ba, 6 = sextuplet; nhịp x/8 tính theo nốt móc đơn)
    HH: x-x-x-x-x-x-x-x-
    SN: ----x-------x---
    BD: x-------x-x-----
    ST: RLRRLRLLRLRRLRLL

    Mỗi ký tự là một ô: x = đánh, X = accent, g = ghost, f = flam, d = drag, z = buzz/press roll, - = nghỉ, | = vạch nhịp (bỏ qua).
    Mã bộ phận: HH hi-hat, OH hi-hat mở, HP hi-hat chân, SN snare, SS side stick, BD kick, T1 tom cao, T2 tom giữa, FT floor tom, RD ride, CR crash.
    Dòng ST là sticking R/L (F = chân), cùng độ dài các dòng khác. Mọi dòng phải dài bằng nhau và đủ trọn ô nhịp (grid × số phách × số ô nhịp).
    Chỉ chép đúng những gì có trên trang; không bịa thêm bài.
    """, """
    Convert the drum exercises on the book page into the text format below. One string per exercise.

    title: <Vietnamese title, e.g. "Stick Control tr.5 #1">
    title_en: <English title, e.g. "Stick Control p5 #1">
    time: 4/4            (time signature)
    tempo: 60-100        (suggested tempo range; if the book says ♩=70 use 70-70)
    grid: 4              (cells per beat: 2 = 8ths, 4 = 16ths, 3 = triplets, 6 = sextuplets; x/8 meters count in 8ths)
    HH: x-x-x-x-x-x-x-x-
    SN: ----x-------x---
    BD: x-------x-x-----
    ST: RLRRLRLLRLRRLRLL

    Each character is a cell: x = hit, X = accent, g = ghost, f = flam, d = drag, z = buzz/press roll, - = rest, | = bar line (ignored).
    Voices: HH hi-hat, OH open hi-hat, HP hi-hat foot, SN snare, SS side stick, BD kick, T1 high tom, T2 mid tom, FT floor tom, RD ride, CR crash.
    The ST line is the sticking R/L (F = foot), same length as the others. Every line must be the same length and fill whole bars.
    Copy only what is on the page; do not invent exercises.
    """) }

    struct Output: Decodable, Sendable { let exercises: [String] }

    static let schema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object(["exercises": .object(["type": .string("array"), "items": .object(["type": .string("string")])])]),
        "required": .array([.string("exercises")]),
        "additionalProperties": .bool(false),
    ])

    public static func transcribe(pagePNG: Data, client: ClaudeClient) async throws(ClaudeError) -> [String] {
        let out = try await client.structured(system: instructions, content: [.imagePNG(pagePNG), .text(L("Chuyển các bài trên trang này.", "Convert the exercises on this page."))],
                                              schema: schema, as: Output.self, effort: .medium, webSearch: false, maxTokens: 16_000)
        return out.exercises.filter { (try? ExerciseDSL.parse($0)) != nil }
    }
}
