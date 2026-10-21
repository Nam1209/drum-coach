import DrumAudio
import DrumCore
import DrumLibrary
import SwiftUI

/// The fundamentals course (from docs/giao-trinh.html): posture, grip, strokes, counting, how to practise.
struct LessonsView: View {
    let voiceBank: CountVoiceBank

    struct Check: Hashable {
        /// Stable key (the Vietnamese text) so saved progress survives a language change.
        let key: String
        let text: String
    }

    struct Lesson: Identifiable {
        let id: Int
        let title: String
        let points: [String]
        let checklist: [Check]
        let practice: (title: String, dsl: String, bpm: Double)?
    }

    private static func c(_ vi: String, _ en: String) -> Check { Check(key: vi, text: L(vi, en)) }

    static var lessons: [Lesson] { [
        Lesson(id: 1, title: L("Tư thế ngồi", "Sitting posture"), points: [
            L("Ghế: đùi song song sàn hoặc hơi dốc xuống về đầu gối.", "Seat: thighs parallel to the floor or sloping slightly down toward the knees."),
            L("Lưng thẳng nhưng không gồng, ngồi nửa trước mặt ghế; vai thả lỏng.", "Back straight but not stiff, sit on the front half of the seat; shoulders relaxed."),
            L("Khuỷu tay buông tự nhiên gần thân.", "Let your elbows hang naturally close to your body."),
            L("Pad 12\" trên chân snare, cao khoảng ngang rốn; cẳng tay gần song song mặt pad.", "12\" pad on the snare stand, about navel height; forearms nearly parallel to the pad."),
            L("Snare của TD-4K chỉnh y như pad để chuyển qua lại không đổi cảm giác.", "Set the TD-4K snare to the same height as the pad so switching feels the same."),
        ], checklist: [c("Vai không nhô lên", "Shoulders not raised"), c("Khuỷu tay sát thân", "Elbows close to the body"), c("Cẳng tay song song mặt pad", "Forearms parallel to the pad")], practice: nil),
        Lesson(id: 2, title: L("Cách cầm dùi (matched grip)", "Holding the sticks (matched grip)"), points: [
            L("Tìm điểm cân bằng: cầm hờ, thả dùi rơi xuống pad, dịch điểm cầm tới chỗ dùi nảy lại nhiều nhất (~1/3 từ đuôi, dùi 5A ≈ 13–14 cm).", "Find the balance point: hold loosely, drop the stick on the pad, and slide your grip to where it rebounds most (~1/3 from the butt, about 13–14 cm on a 5A)."),
            L("Kẹp giữa mặt phẳng đầu ngón cái và đốt giữa ngón trỏ — đây là điểm tựa duy nhất.", "Pinch between the flat of your thumb tip and the middle joint of your index finger. This is the only fulcrum."),
            L("Ba ngón còn lại ôm nhẹ để dẫn hướng; lòng bàn tay còn khoảng hở.", "The other three fingers wrap lightly to guide; keep a gap in your palm."),
            L("Lực nắm chỉ 2–3/10.", "Grip pressure is only 2–3 out of 10."),
            L("American grip: mu bàn tay nghiêng ~45°, hai dùi thành chữ V 60–90°.", "American grip: backs of the hands tilted ~45°, sticks forming a 60–90° V."),
            L("Lỗi hay gặp: nắm chặt, điểm tựa trượt, ngón cái chĩa lên, đuôi dùi thúc vào cổ tay.", "Common mistakes: gripping tight, a sliding fulcrum, thumb pointing up, the stick butt jabbing into the wrist."),
        ], checklist: [c("Dùi nảy lại tự do", "Stick rebounds freely"), c("Hai tay cầm giống nhau", "Both hands hold the same"), c("Không có khe hở ở điểm tựa", "No gap at the fulcrum")], practice: nil),
        Lesson(id: 3, title: L("Cú đánh: để dùi nảy lại", "The stroke: let the stick rebound"), points: [
            L("Ném dùi xuống rồi để nó tự nảy lên; không ấn, không giật.", "Throw the stick down and let it bounce back up; don't press, don't yank."),
            L("Full (cao→cao), Down (cao→chặn thấp), Tap (thấp→thấp), Up (thấp→nhấc cao).", "Full (high→high), Down (high→stop low), Tap (low→low), Up (low→lift high)."),
            L("Độ cao dùi quyết định độ to: accent 25–30 cm, thường 10–15 cm, ghost 3–5 cm.", "Stick height sets volume: accent 25–30 cm, normal 10–15 cm, ghost 3–5 cm."),
            L("Chủ yếu dùng cổ tay; đánh vào cùng một điểm gần tâm pad.", "Mostly use the wrist; hit the same spot near the center of the pad."),
            L("Stone: tập với cơ thả lỏng, dừng ngay khi thấy căng.", "Stone: practice with relaxed muscles and stop as soon as you feel tension."),
        ], checklist: [c("Hai tay cùng tiếng", "Both hands sound the same"), c("Dùi về đúng độ cao", "Stick returns to the right height"), c("Không căng vai/cổ tay", "No tension in shoulders or wrists")],
               practice: (L("Chỉ tay phải rồi chỉ tay trái", "Right hand only, then left hand only"), "title: Tay phải / tay trái\ntitle_en: Right hand / left hand\ntime: 4/4\ntempo: 50-70\ngrid: 1\nSN: xxxx|xxxx\nST: RRRR|LLLL", 50)),
        Lesson(id: 4, title: L("Đếm và nghe beat", "Counting and hearing the beat"), points: [
            L("Nói liền một hơi như hát: \"one-and-two-and…\", \"&\" nhỏ hơn số và nằm đúng giữa hai phách.", "Say it in one flowing breath like singing: \"one-and-two-and…\". The \"&\" is quieter than the numbers and sits exactly between two beats."),
            L("Nghe app đếm → đếm cùng → giọng nhỏ dần → tự đếm (tab Đếm nhịp).", "Listen to the app count → count along → fade your voice → count alone (Counting tab)."),
            L("Gót chân trái gõ nhẹ các số 1 2 3 4; \"&\" là lúc chân nhấc cao nhất.", "Tap your left heel lightly on 1 2 3 4; the \"&\" is when your foot is highest."),
            L("\"Nhấn chìm\" tiếng click: đánh đúng thì gần như không nghe thấy click.", "\"Drown\" the click: when you play on time you barely hear it."),
            L("Tắt bớt click: chỉ phách 2 và 4, rồi chỉ phách 1, rồi Gap.", "Thin out the click: only beats 2 and 4, then only beat 1, then Gap."),
        ], checklist: [c("Đếm không ngắt ở \"&\"", "Counting doesn't break at the \"&\""), c("Count Coach > 90% ở 60 BPM", "Count Coach above 90% at 60 BPM")],
               practice: (L("Chỉ đánh vào \"&\"", "Play only the \"&\""), "title: Chỉ đánh vào &\ntitle_en: Play only the &\ntime: 4/4\ntempo: 50-80\ngrid: 2\nSN: -x-x-x-x\nST: -L-L-L-L", 60)),
        Lesson(id: 5, title: L("Tập Stick Control đúng cách", "Practicing Stick Control properly"), points: [
            L("Mỗi bài lặp 20 lần không dừng rồi mới sang bài kế tiếp.", "Repeat each exercise 20 times without stopping before moving on."),
            L("Bắt đầu trang 5 (Single Beat Combinations), đọc từ trên xuống.", "Start on page 5 (Single Beat Combinations) and read from the top down."),
            L("Tập nhiều tempo: rất chậm → nhanh dần → chậm lại; dùng tempo ramp 50 → 90.", "Practice at many tempos: very slow → faster → slow again; use a tempo ramp 50 → 90."),
            L("Tập cả nhẹ (đánh thấp), không chỉ đánh mạnh.", "Practice soft too (low strokes), not just loud."),
            L("Nâng cao: tay phải sang hi-hat, tay trái giữ snare, thêm kick phách 1 và 3.", "Advanced: right hand on hi-hat, left hand on snare, add kick on beats 1 and 3."),
        ], checklist: [c("4 bài × 20 lần mỗi ngày", "4 exercises × 20 times a day")], practice: nil),
        Lesson(id: 6, title: L("Tập theo Rockschool", "Practicing for Rockschool"), points: [
            L("Bài kỹ thuật đúng tempo sách (G1–2 ♩=70, G3–4 ♩=75), phải chơi được ngay khi giám khảo chọn.", "Play technical exercises at the book tempo (G1–2 ♩=70, G3–4 ♩=75), ready the moment the examiner picks one."),
            L("Fill test: 3 ô groove rồi fill, về lại phách 1 không hụt nhịp.", "Fill test: 3 bars of groove then the fill, back on beat 1 without losing time."),
            L("Kick cùng crash/snare phải vang cùng lúc, không thành flam ngoài ý muốn.", "Kick with crash/snare must land together, not as an accidental flam."),
            L("Đếm to móc kép khi tập đoạn khó; tập chậm rồi tăng dần.", "Count 16th notes out loud on hard passages; practice slowly, then speed up."),
            L("Ear Test: Fill Playback và Groove Recall — luyện trong tab Level.", "Ear test: Fill Playback and Groove Recall. Train them in the Levels tab."),
        ], checklist: [c("Mọi bài test level > 90%", "Every level test above 90%")], practice: nil),
        Lesson(id: 7, title: L("Lịch 30 phút/ngày", "A 30-minute daily schedule"), points: [
            L("0–5: khởi động single/double, nốt đen → móc đơn → móc kép, đếm thành tiếng.", "0–5: warm up with singles/doubles, quarter notes → 8th notes → 16th notes, counting out loud."),
            L("5–15: Stick Control 4 bài × 20 lần.", "5–15: Stick Control, 4 exercises × 20 times."),
            L("15–25: Rockschool grade hiện tại đúng tempo thi.", "15–25: your current Rockschool grade at exam tempo."),
            L("25–30: Count Coach hoặc đọc nhạc, ghi âm 1 lượt.", "25–30: Count Coach or sight-reading, record one take."),
        ], checklist: [c("Bấm \"Bắt đầu buổi tập\" ở tab Hôm nay", "Tap \"Start session\" on the Today tab")], practice: nil),
        Lesson(id: 8, title: L("Roland TD-4K với iPad", "Roland TD-4K with iPad"), points: [
            L("TD-4K chỉ có MIDI OUT 5 chân: cần cáp USB-MIDI (vd. Roland UM-ONE) + adapter USB-C.", "The TD-4K only has a 5-pin MIDI OUT: you need a USB-MIDI cable (e.g. Roland UM-ONE) plus a USB-C adapter."),
            L("Pedal hi-hat FD-8 do mô-đun TD-4 tự xử lý: nó gửi sẵn nốt hi-hat đóng hoặc mở, nên không cần bật \"Hi-hat theo pedal (CC4)\" trong Cài đặt.", "The TD-4 module handles the FD-8 hi-hat pedal itself and already sends closed or open hi-hat notes, so leave \"Hi-hat by pedal (CC4)\" off in Settings."),
            L("Cắm cáp là app tự nhận từng trống theo bảng nốt mặc định của Roland. Vào Cài đặt → MIDI learn để kiểm tra: pad nào hiện \"chưa gán\" thì bấm Học rồi đánh pad đó.", "Once the cable is in, the app recognises each drum from Roland's default note map. Check it in Settings → MIDI learn: if a pad shows \"not mapped\", tap Learn and hit that pad."),
            L("Chưa có cáp: dùng micro như pad tập (chấm sớm/muộn, không biết trống nào).", "No cable yet: use the microphone like a practice pad (early/late scoring, but it can't tell which drum)."),
        ], checklist: [c("Mọi pad đều được nhận đúng trống", "Every pad is recognised as the right drum"), c("Hiệu chỉnh độ trễ cho trống điện", "Latency calibration for the e-drum kit")], practice: nil),
    ] }

    @AppStorage("lessonChecks") private var checksRaw = ""

    var body: some View {
        let lesson = Self.lessons.first { $0.id == selected } ?? Self.lessons[0]
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: L("Bài học", "Lessons"), subtitle: L("Nền tảng trước khi tăng tốc", "Foundations before you speed up"))
                HStack(alignment: .top, spacing: 22) {
                    lessonList.frame(maxWidth: 340)
                    detail(lesson)
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.canvas)
    }

    @State private var selected = 1

    private var lessonList: some View {
        VStack(spacing: 0) {
            ForEach(Self.lessons) { l in
                let done = !l.checklist.isEmpty && l.checklist.allSatisfy { checks.contains("\(l.id):\($0.key)") }
                Button { selected = l.id } label: {
                    HStack(spacing: 14) {
                        Text("\(l.id)").font(Theme.number(15, weight: .medium)).foregroundStyle(.secondary).frame(width: 20)
                        Text(l.title).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Spacer()
                        if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.onTime) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(selected == l.id ? Theme.shell.opacity(0.12) : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if l.id != Self.lessons.last?.id { Divider().padding(.leading, 50) }
            }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.stage))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detail(_ lesson: Lesson) -> some View {
        Stage {
            VStack(alignment: .leading, spacing: 16) {
                Text(lesson.title).font(.title2.weight(.bold))
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(lesson.points, id: \.self) { point in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle().fill(Theme.shell).frame(width: 6, height: 6).offset(y: -3)
                            Text(point)
                        }
                    }
                }
                Divider()
                Text(L("Tự kiểm tra", "Self-check")).font(.headline)
                ForEach(lesson.checklist, id: \.key) { item in
                    let key = "\(lesson.id):\(item.key)"
                    Button { toggle(key) } label: {
                        Label(item.text, systemImage: checks.contains(key) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checks.contains(key) ? Theme.onTime : .primary)
                    }
                    .buttonStyle(.plain)
                }
                if let p = lesson.practice, let ex = try? ExerciseDSL.parse(p.dsl) {
                    NavigationLink { PracticeView(exercises: [ex], voiceBank: voiceBank, bpm: p.bpm) } label: {
                        Text(L("Tập ngay: \(p.title)", "Practice now: \(p.title)")).font(.callout.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(Capsule().fill(Theme.shell)).foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var checks: Set<String> { Set(checksRaw.split(separator: "|").map(String.init)) }
    private func toggle(_ key: String) {
        var c = checks
        if c.contains(key) { c.remove(key) } else { c.insert(key) }
        checksRaw = c.sorted().joined(separator: "|")
    }
}
