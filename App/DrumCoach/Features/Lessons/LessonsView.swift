import DrumAudio
import DrumCore
import DrumLibrary
import SwiftUI

/// The fundamentals course (from docs/giao-trinh.html): posture, grip, strokes, counting, how to practise.
struct LessonsView: View {
    let voiceBank: CountVoiceBank

    struct Lesson: Identifiable {
        let id: Int
        let title: String
        let points: [String]
        let checklist: [String]
        let practice: (title: String, dsl: String, bpm: Double)?
    }

    static let lessons: [Lesson] = [
        Lesson(id: 1, title: "Tư thế ngồi", points: [
            "Ghế: đùi song song sàn hoặc hơi dốc xuống về đầu gối.",
            "Lưng thẳng nhưng không gồng, ngồi nửa trước mặt ghế; vai thả lỏng.",
            "Khuỷu tay buông tự nhiên gần thân.",
            "Pad 12\" trên chân snare, cao khoảng ngang rốn; cẳng tay gần song song mặt pad.",
            "Snare của TD-7 chỉnh y như pad để chuyển qua lại không đổi cảm giác.",
        ], checklist: ["Vai không nhô lên", "Khuỷu tay sát thân", "Cẳng tay song song mặt pad"], practice: nil),
        Lesson(id: 2, title: "Cách cầm dùi (matched grip)", points: [
            "Tìm điểm cân bằng: cầm hờ, thả dùi rơi xuống pad, dịch điểm cầm tới chỗ dùi nảy lại nhiều nhất (~1/3 từ đuôi, dùi 5A ≈ 13–14 cm).",
            "Kẹp giữa mặt phẳng đầu ngón cái và đốt giữa ngón trỏ — đây là điểm tựa duy nhất.",
            "Ba ngón còn lại ôm nhẹ để dẫn hướng; lòng bàn tay còn khoảng hở.",
            "Lực nắm chỉ 2–3/10.",
            "American grip: mu bàn tay nghiêng ~45°, hai dùi thành chữ V 60–90°.",
            "Lỗi hay gặp: nắm chặt, điểm tựa trượt, ngón cái chĩa lên, đuôi dùi thúc vào cổ tay.",
        ], checklist: ["Dùi nảy lại tự do", "Hai tay cầm giống nhau", "Không có khe hở ở điểm tựa"], practice: nil),
        Lesson(id: 3, title: "Cú đánh: để dùi nảy lại", points: [
            "Ném dùi xuống rồi để nó tự nảy lên; không ấn, không giật.",
            "Full (cao→cao), Down (cao→chặn thấp), Tap (thấp→thấp), Up (thấp→nhấc cao).",
            "Độ cao dùi quyết định độ to: accent 25–30 cm, thường 10–15 cm, ghost 3–5 cm.",
            "Chủ yếu dùng cổ tay; đánh vào cùng một điểm gần tâm pad.",
            "Stone: tập với cơ thả lỏng, dừng ngay khi thấy căng.",
        ], checklist: ["Hai tay cùng tiếng", "Dùi về đúng độ cao", "Không căng vai/cổ tay"],
               practice: ("Chỉ tay phải rồi chỉ tay trái", "title: Tay phải / tay trái\ntime: 4/4\ntempo: 50-70\ngrid: 1\nSN: xxxx|xxxx\nST: RRRR|LLLL", 50)),
        Lesson(id: 4, title: "Đếm và nghe beat", points: [
            "Nói liền một hơi như hát: \"one-and-two-and…\", \"&\" nhỏ hơn số và nằm đúng giữa hai phách.",
            "Nghe app đếm → đếm cùng → giọng nhỏ dần → tự đếm (tab Đếm nhịp).",
            "Gót chân trái gõ nhẹ các số 1 2 3 4; \"&\" là lúc chân nhấc cao nhất.",
            "\"Nhấn chìm\" tiếng click: đánh đúng thì gần như không nghe thấy click.",
            "Tắt bớt click: chỉ phách 2 và 4, rồi chỉ phách 1, rồi Gap.",
        ], checklist: ["Đếm không ngắt ở \"&\"", "Count Coach > 90% ở 60 BPM"],
               practice: ("Chỉ đánh vào \"&\"", "title: Chỉ đánh vào &\ntime: 4/4\ntempo: 50-80\ngrid: 2\nSN: -x-x-x-x\nST: -L-L-L-L", 60)),
        Lesson(id: 5, title: "Tập Stick Control đúng cách", points: [
            "Mỗi bài lặp 20 lần không dừng rồi mới sang bài kế tiếp.",
            "Bắt đầu trang 5 (Single Beat Combinations), đọc từ trên xuống.",
            "Tập nhiều tempo: rất chậm → nhanh dần → chậm lại; dùng tempo ramp 50 → 90.",
            "Tập cả nhẹ (đánh thấp), không chỉ đánh mạnh.",
            "Nâng cao: tay phải sang hi-hat, tay trái giữ snare, thêm kick phách 1 và 3.",
        ], checklist: ["4 bài × 20 lần mỗi ngày"], practice: nil),
        Lesson(id: 6, title: "Tập theo Rockschool", points: [
            "Bài kỹ thuật đúng tempo sách (G1–2 ♩=70, G3–4 ♩=75), phải chơi được ngay khi giám khảo chọn.",
            "Fill test: 3 ô groove rồi fill, về lại phách 1 không hụt nhịp.",
            "Kick cùng crash/snare phải vang cùng lúc, không thành flam ngoài ý muốn.",
            "Đếm to móc kép khi tập đoạn khó; tập chậm rồi tăng dần.",
            "Ear Test: Fill Playback và Groove Recall — luyện trong tab Level.",
        ], checklist: ["Mọi bài test level > 90%"], practice: nil),
        Lesson(id: 7, title: "Lịch 30 phút/ngày", points: [
            "0–5: khởi động single/double, nốt đen → móc đơn → móc kép, đếm thành tiếng.",
            "5–15: Stick Control 4 bài × 20 lần.",
            "15–25: Rockschool grade hiện tại đúng tempo thi.",
            "25–30: Count Coach hoặc đọc nhạc, ghi âm 1 lượt.",
        ], checklist: ["Bấm \"Bắt đầu buổi tập\" ở tab Hôm nay"], practice: nil),
        Lesson(id: 8, title: "Roland TD-7 với iPad", points: [
            "TD-7 chỉ có MIDI OUT 5 chân: cần cáp USB-MIDI (vd. Roland UM-ONE) + adapter USB-C.",
            "Vào Cài đặt → MIDI learn, đánh từng pad một lần.",
            "Chưa có cáp: dùng micro như pad tập (chấm sớm/muộn, không biết trống nào).",
        ], checklist: ["MIDI learn đủ các pad", "Hiệu chỉnh độ trễ cho trống điện"], practice: nil),
    ]

    @AppStorage("lessonChecks") private var checksRaw = ""

    var body: some View {
        List(Self.lessons) { lesson in
            NavigationLink("\(lesson.id). \(lesson.title)") {
                List {
                    Section("Nội dung") { ForEach(lesson.points, id: \.self) { Text("• " + $0) } }
                    Section("Tự kiểm tra") {
                        ForEach(lesson.checklist, id: \.self) { item in
                            let key = "\(lesson.id):\(item)"
                            Button { toggle(key) } label: {
                                Label(item, systemImage: checks.contains(key) ? "checkmark.square.fill" : "square")
                            }
                        }
                    }
                    if let p = lesson.practice, let ex = try? ExerciseDSL.parse(p.dsl) {
                        Section {
                            NavigationLink("Tập ngay: \(p.title)") { PracticeView(exercises: [ex], voiceBank: voiceBank, bpm: p.bpm) }
                        }
                    }
                }
                .navigationTitle(lesson.title)
            }
        }
        .navigationTitle("Bài học nền tảng")
    }

    private var checks: Set<String> { Set(checksRaw.split(separator: "|").map(String.init)) }
    private func toggle(_ key: String) {
        var c = checks
        if c.contains(key) { c.remove(key) } else { c.insert(key) }
        checksRaw = c.sorted().joined(separator: "|")
    }
}
