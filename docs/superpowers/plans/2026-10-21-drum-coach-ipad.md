# DrumCoach (iPad) – Plan triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng sub-skill superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm plan này theo từng task. Các bước dùng checkbox (`- [ ]`) để theo dõi.

**Mục tiêu:** Một app iPad giúp tự học trống hướng tới Rockschool Grade 8: metronome, đếm nhịp bằng giọng nói, hiển thị bài tập trên khuông nhạc với con trỏ chạy theo tempo, nghe người chơi (trống điện qua MIDI hoặc pad qua micro), đo sớm/trễ từng nốt, và dùng Claude để đánh giá trình độ theo tiêu chí Rockschool.

**Kiến trúc:** Toàn bộ logic thuần (model, parser, lịch phát click, phát hiện tiếng gõ, so khớp nốt, chấm điểm, client Claude) nằm trong Swift package `DrumKit`, test được bằng `swift test` trên Mac, không cần simulator. App SwiftUI `DrumCoach` chỉ là lớp mỏng nối các phần đó với AVAudioEngine, CoreMIDI, SwiftData và giao diện. Mọi mốc thời gian đều quy về **host time tính bằng giây** (`HostClock`), để click của metronome, sự kiện MIDI và tiếng gõ thu từ micro so sánh được với nhau.

**Tech stack:** Swift 6.4, SwiftUI, Swift Testing (`import Testing`), AVFoundation (AVAudioEngine, AVSpeechSynthesizer), CoreMIDI, SwiftData, Swift Charts, PDFKit, URLSession → Claude Messages API, XcodeGen (sinh `.xcodeproj` từ `project.yml`).

**Spec:** Không có file spec riêng. Người dùng chọn bỏ qua phần hỏi đáp. Yêu cầu gốc (hội thoại ngày 2026-10-21) được tóm tắt ở mục "Yêu cầu" bên dưới; plan này lập luận dựa trên đó.

## Yêu cầu (từ người dùng)

1. Metronome.
2. Chọn chế độ tập: **pad** (nghe bằng micro) hoặc **trống điện** (MIDI).
3. Hiển thị bài tập trên khuông nhạc, chạy theo từng nốt ở các tempo khác nhau (giống video "24K Magic": con trỏ dọc chạy qua, nốt đang đánh sáng lên, có nhãn HI-HAT/SNARE).
4. Tạo bài tập dựa trên Stick Control (George Lawrence Stone) và tài liệu Rockschool Drums. Mục tiêu là Grade 8.
5. Nghe lúc người dùng chơi, hiển thị đánh sớm hay trễ so với tempo, và đánh giá trình độ theo Rockschool (có thể dùng Claude AI).
6. Hỗ trợ đếm nhịp bằng giọng: `1 2 3 4`, `1 & 2 & …`, `1 e & a …` (và chùm ba `1 trip let`) ở mọi tempo.

**Bối cảnh người dùng (người dùng kể thêm):**
- Tập trên **cả pad lẫn trống điện**; tempo hiện tại thoải mái ở **50–90 BPM**.
- Đang tập theo **Stick Control**.
- **Chưa biết mình đang ở trình độ nào** → cần bài kiểm tra xếp trình độ (Task 10A) trước khi đặt lộ trình lên Grade 8.
- **Đếm nhịp thành tiếng chưa đều:** bị giật, ngắt quãng ở âm "&", nghe không mượt. Vì vậy giọng đếm mẫu của app phải liền mạch và tự nhiên (Task 3), và cần chế độ luyện đếm có micro chấm điểm (Task 7A).
- Bị bí ở nhiều chỗ → app cần chỉ ra điểm yếu cụ thể (theo vị trí "1 e & a", theo tay R/L) và gợi ý bài tiếp theo.
- Vì tempo đang là 50–90, mặc định của app phải tối ưu cho khoảng này: tempo ramp mặc định 50 → 90, bước +2.

**Yêu cầu bổ sung (người dùng đang dùng app Drum Journal để tham khảo):**
- Nốt chạy theo tempo để tập theo. Người dùng **đeo tai nghe** để nghe metronome; iPad dùng **micro** nghe tiếng trống (cả pad lẫn trống điện).
- Màu phản hồi cho từng nốt:
  - **Xanh lá** = đúng.
  - **Cam** = sớm hoặc muộn. Vạch cam đặt **trước nốt** nếu sớm, **sau nốt** nếu muộn.
  - **Đỏ** = trượt.
- Cuối bài hiện **% hoàn thành** trên tổng số nốt của bài.
- Có **danh sách bài test cho từng level**. Chỉ **đạt level khi được > 90%** ở bài test của level đó.
- Học theo giao diện Drum Journal:
  - Chữ R/L dưới nốt.
  - Dải thời gian hai làn R (trên) và L (dưới), có nhãn đếm "1 & 2 &" chạy qua vạch đứng.
  - Nút BPM −/+ và chọn thời lượng bài (30 giây, 1, 2, 5 phút).
  - Chọn giá trị nốt (đen / móc đơn / móc kép).
  - Nút FLIP để đổi tay (R↔L).
  - Banner "Nên dùng tai nghe".
  - Dòng "Lần trước: 50 BPM, 79%" kèm biểu đồ nhỏ.

**Giáo viên AI (người dùng: "tôi không có giáo viên thực tế, nên giáo viên AI khá quan trọng"):**
- **Lưu lịch sử tập lâu dài**, không giới hạn thời gian, và **lưu từ buổi tập đầu tiên**. Vì vậy việc lưu mỗi lần chơi được đưa vào Task 7, không đợi tới cuối.
- AI đọc lịch sử dài hạn, chỉ ra **cần sửa gì**, **lên kế hoạch tập**, và **gợi ý video YouTube hoặc tài liệu**.
- Có thêm buổi tập có cấu trúc ("Hôm nay tập gì") và thư viện 40 rudiment PAS (từ phần tham khảo Drumeo).

**Tài liệu và thiết bị người dùng cung cấp (2026-10-21):**
- **Tài liệu:** Stick Control (bản scan PDF) và Rockschool Drums Grade 1–4 (PDF).
- **Grade 5–8:** người dùng sẽ upload sau. Họ yêu cầu: "báo tôi khi tôi đạt grade 6, tôi sẽ upload doc 6,7,8". Hiện **chưa có sách Grade 5**.
- **Thiết bị:** Roland **TD-7** (chỉ có MIDI OUT 5 chân, cần cáp USB-MIDI), pad 12", dùi 5A.
- **Cấu trúc thi Rockschool thật (lấy từ sách):**
  - Grade 1–5: 3 bài biểu diễn (3×20 điểm), Technical Exercises (15), Sight Reading hoặc Improvisation & Interpretation (10), Ear Tests (10), GMQ (5).
  - Grade 6–8: Sight Reading / I&I được thay bằng Quick Study Piece.
  - Mức điểm: Pass 60%, Merit 74%, Distinction 90%.
  - Tempo bài kỹ thuật: G1–2 ♩=70, G3–4 ♩=75; fill test ♩=70–80.
  - Ear Test gồm: Fill Playback & Recognition, Groove Recall.
- **Giáo trình nền tảng** (tư thế, cầm dùi, cú đánh, đếm, cách tập Stick Control/Rockschool) nằm ở `docs/giao-trinh.html`. Task 16 đưa nội dung này vào app.

**Các quyết định Claude tự đưa ra (người dùng có thể đổi):**
- **Level = Rockschool Grade 1…8.** Nội dung test lấy từ Technical Exercises và Fill của sách tương ứng, ở đúng tempo của sách. Quy tắc "trên 90% mới đạt" trùng với mức Distinction. Bảng 8 level tự soạn ở Task 10A chỉ dùng cho grade nào chưa có sách.
- **Nội dung chép từ sách không commit vào git.** Bài tập chuyển từ sách (DSL) nằm trong `PrivateLibrary/` (được `.gitignore` bỏ qua), app nạp lúc chạy. Repo chỉ chứa code và bài do app tự soạn.
- **Thông báo thiếu sách:** khi người dùng đạt grade N mà chưa có sách grade N+1, app hiện "Hãy upload sách Grade N+1". Riêng khi đạt Grade 5, app nhắc upload Grade 6, 7, 8 (theo yêu cầu). Sách Grade 5 hiện còn thiếu nên app sẽ nhắc ngay khi đạt Grade 4.
- **Ngưỡng "đúng":** |lệch| ≤ 30 ms, chỉnh được trong Settings (Dễ 45 / Vừa 30 / Khó 20 ms). Lệch lớn hơn nhưng vẫn nằm trong cửa sổ ghép là cam; ngoài cửa sổ là đỏ.
- **Cách tính %:** mỗi nốt xanh được 1 điểm, cam 0.5, đỏ 0. % = tổng điểm / tổng số nốt × 100. Cú đánh thừa trừ 0.5 điểm mỗi cú. Kết quả kẹp trong 0…100.
- Native Swift/SwiftUI vì cần độ trễ âm thanh thấp và CoreMIDI.
- **Bản quyền:** Stick Control và sách Rockschool vẫn còn bản quyền, nên app **không đóng gói nội dung của chúng**. Có ba nguồn bài tập: (a) generator tự sinh các hoán vị sticking theo kiểu Stick Control (đây là tổ hợp toán học R/L, không chép sách); (b) bộ giáo trình kỹ năng Grade 8 do app tự soạn; (c) người dùng nhập bài từ sách của chính mình, bằng tay qua text DSL hoặc dùng Claude đọc trang PDF. Dữ liệu nhập chỉ nằm trên máy.
- Đếm nhịp bằng tiếng Anh ("one, e, and, a"), vì đó là chuẩn mà Rockschool dùng; tiếng Việt để sau.
- API key Claude do người dùng nhập trong Settings và lưu trong Keychain (app cá nhân, không có backend).

## Global Constraints

- iPadOS deployment target **18.0**; thiết bị chỉ iPad (`TARGETED_DEVICE_FAMILY = 2`); chạy được cả ngang lẫn dọc.
- Swift 6 language mode, strict concurrency bật.
- Package `DrumKit` **không import UIKit/SwiftUI**. Module `DrumCore`, `DrumAnalysis`, `DrumLibrary` không import AVFoundation, để `swift test` chạy được trên macOS.
- Platform của package: `.iOS(.v18), .macOS(.v15)`.
- Không dùng dependency bên thứ ba trong runtime (chỉ dùng XcodeGen lúc build).
- Mọi thời gian dùng kiểu `TimeInterval` (giây, host time). Chuyển sang ms chỉ ở tầng hiển thị.
- **AI:** Claude API gọi bằng HTTP thuần qua URLSession (Swift không có SDK chính thức). Endpoint `https://api.anthropic.com/v1/messages`, header `anthropic-version: 2023-06-01`.
- **Model mặc định cho mọi tính năng là `claude-opus-5-5`.** Settings cho phép đổi sang `claude-sonnet-5-5` để tiết kiệm. Dùng `thinking: {type: "adaptive"}`. Đặt `output_config.effort` rõ ràng (vì mặc định của Opus 5.5 là `medium`): báo cáo tuần và test level dùng `high`, chat dùng `low`, đọc PDF dùng `medium`.
- **Không dùng `tool_choice` kiểu `tool`/`any`**: Opus 5.5 và Sonnet 5.5 trả về lỗi 400. Ép JSON bằng structured outputs `output_config: {format: {type: "json_schema", schema: …}}`.
- **Web search:** server tool `{"type": "web_search_20260209", "name": "web_search", "max_uses": 5}`. Lỗi của tool trả về trong block `web_search_tool_result` (HTTP 200), không phải exception.
- **Refusal fallback:** gửi header `anthropic-beta: server-side-fallback-2026-07-01` cùng `fallbacks: "default"`. Luôn kiểm tra `stop_reason == "refusal"` trước khi đọc `content`.
- Prompt caching: system prompt và ngữ pháp DSL cố định ở đầu request, đặt `cache_control: {type: "ephemeral"}`, không chèn timestamp vào system.
- Chữ trong UI viết bằng tiếng Việt. Thuật ngữ trống giữ nguyên tiếng Anh (Hi-Hat, Snare, Kick, Paradiddle, Flam…).
- Không ship bất kỳ văn bản hay bài nhạc nào chép từ Stick Control hoặc Rockschool.

## Review Focus

1. **Tempo cực trị** (40 và 300 BPM, nốt 32nd ở 200 BPM): lịch click không được trôi; sau 10 phút sai lệch tích lũy phải dưới 1 sample. Test được thêm ở Task 3.
2. **Tiếng metronome lọt vào micro** khi người dùng quên đeo tai nghe sẽ làm điểm cao giả. App phát hiện đầu ra đang là loa (`AVAudioSession.currentRoute`) thì hiện banner "Nên dùng tai nghe" và bật cửa sổ chặn quanh mỗi click. Test được thêm ở Task 6.
3. **Đánh thừa hoặc đánh thiếu nốt:** một cú đánh thừa không được "ăn" mất nốt kế tiếp, và nốt bị bỏ phải ghi là `missed` chứ không bị ghép với cú đánh ở xa. Test được thêm ở Task 7.
4. **Đổi tempo hoặc dừng giữa chừng:** dữ liệu phân tích của lần chơi trước không được lẫn vào lần chơi mới. Test được thêm ở Task 7.
5. **Claude trả về JSON hỏng, thiếu field hoặc mất mạng:** app hiện lỗi dễ hiểu và vẫn giữ kết quả phân tích cục bộ. Test được thêm ở Task 10.

---

## Cấu trúc file

```
drum/
├── project.yml                        # XcodeGen: target app DrumCoach
├── Packages/DrumKit/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── DrumCore/
│   │   │   ├── Voice.swift            # các bộ phận trống + vị trí trên khuông + MIDI note
│   │   │   ├── Exercise.swift         # Exercise, NoteEvent, TimeSignature, Subdivision
│   │   │   ├── ExerciseDSL.swift      # parse/serialize định dạng text của bài tập
│   │   │   ├── Timeline.swift         # nốt → thời điểm (giây) theo tempo
│   │   │   └── Counting.swift         # nhãn đếm "1 e & a", "1 trip let"
│   │   ├── DrumAudio/                 # được phép import AVFoundation
│   │   │   ├── ClickSchedule.swift    # thuần: sinh danh sách click theo sample time
│   │   │   ├── MetronomeEngine.swift  # AVAudioEngine: phát click và giọng đếm
│   │   │   ├── CountVoiceBank.swift   # render AVSpeechSynthesizer ra buffer
│   │   │   ├── HostClock.swift
│   │   │   ├── MicOnsetSource.swift   # input tap → OnsetDetector
│   │   │   └── MIDIHitSource.swift    # CoreMIDI → Hit
│   │   ├── DrumAnalysis/
│   │   │   ├── Hit.swift
│   │   │   ├── OnsetDetector.swift    # thuần: phát hiện tiếng gõ trên mảng Float
│   │   │   ├── HitMatcher.swift       # ghép cú đánh với nốt mong đợi
│   │   │   ├── SessionStats.swift     # trung bình/độ lệch, sớm/trễ, % chính xác
│   │   │   └── LatencyCalibrator.swift
│   │   ├── DrumLibrary/
│   │   │   ├── StickingGenerator.swift
│   │   │   ├── Grade8Curriculum.swift
│   │   │   └── TempoTrainer.swift     # tempo ramp, gap click
│   │   └── DrumAI/
│   │       ├── ClaudeClient.swift
│   │       ├── AssessmentRequest.swift
│   │       └── PageTranscriber.swift  # trang PDF → DSL
│   └── Tests/ (mỗi module một thư mục: DrumCoreTests, DrumAnalysisTests, …)
└── App/DrumCoach/
    ├── DrumCoachApp.swift
    ├── Models/ (SwiftData: StoredExercise, PracticeSession)
    ├── Features/
    │   ├── Practice/  (PracticeView, PracticeViewModel, NotationView, TimingStrip)
    │   ├── Library/   (LibraryView, ExerciseEditorView, PDFImportView)
    │   ├── Progress/  (ProgressView với Swift Charts)
    │   └── Settings/  (SettingsView, CalibrationView)
    └── Resources/ (click_hi.wav, click_lo.wav, Assets.xcassets)
```

---

## Mốc 1: Nền tảng

### Task 1: Dựng project + model cốt lõi

**Files:**
- Create: `project.yml`, `Packages/DrumKit/Package.swift`, `Sources/DrumCore/Voice.swift`, `Sources/DrumCore/Exercise.swift`, `App/DrumCoach/DrumCoachApp.swift` (màn hình trống "DrumCoach"), `.gitignore`
- Test: `Packages/DrumKit/Tests/DrumCoreTests/ExerciseTests.swift`

**Interfaces – Produces:**
```swift
public enum Voice: String, Codable, CaseIterable, Sendable {
  case kick, snare, hiHat, hiHatOpen, hiHatPedal, tom1, tom2, floorTom, ride, crash, sideStick
  public var staffStep: Int      // 0 = dòng dưới cùng, mỗi bước là 1 dòng hoặc khe
  public var usesXNotehead: Bool // hi-hat, ride, crash → nốt hình chữ x
  public var displayName: String // "HI-HAT", "SNARE"…
  public static func from(midiNote: UInt8) -> Voice? // theo map General MIDI drum
}
public enum Hand: String, Codable, Sendable { case right = "R", left = "L", foot = "F" }
public enum Articulation: String, Codable, Sendable { case normal, accent, ghost, flam, drag, buzz }
public struct TimeSignature: Codable, Hashable, Sendable { public var beats: Int; public var unit: Int } // 4/4, 7/8
public struct NoteEvent: Codable, Hashable, Sendable {
  public var position: Rational      // vị trí tính bằng phách, từ đầu bài (ví dụ 3/4 = phách 0 + 3/4)
  public var voice: Voice
  public var hand: Hand?
  public var articulation: Articulation
}
public struct Rational: Codable, Hashable, Comparable, Sendable { public var num: Int; public var den: Int } // luôn ở dạng tối giản
public struct Exercise: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID; public var title: String; public var source: String // "Stick Control-style", "Grade 8 – Linear", "User"
  public var timeSignature: TimeSignature; public var bars: Int
  public var suggestedTempo: ClosedRange<Int>; public var notes: [NoteEvent]
}
```

- [ ] **Bước 1:** `git init`, chạy `brew install xcodegen`, tạo `Package.swift` với 5 target (DrumCore, DrumAudio, DrumAnalysis, DrumLibrary, DrumAI) kèm test target tương ứng, tạo `project.yml` với app target phụ thuộc local package. Lệnh `xcodegen generate && xcodebuild -scheme DrumCoach -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build` phải ra **BUILD SUCCEEDED**.
- [ ] **Bước 2: Viết test fail**
```swift
@Test func rationalNormalizes() { #expect(Rational(2, 8) == Rational(1, 4)); #expect(Rational(1,2) < Rational(3,4)) }
@Test func midiMapping() { #expect(Voice.from(midiNote: 38) == .snare); #expect(Voice.from(midiNote: 36) == .kick); #expect(Voice.from(midiNote: 42) == .hiHat); #expect(Voice.from(midiNote: 46) == .hiHatOpen); #expect(Voice.from(midiNote: 51) == .ride); #expect(Voice.from(midiNote: 0) == nil) }
@Test func exerciseRoundTripsJSON() throws { /* encode rồi decode một Exercise có 2 nốt → bằng nhau */ }
@Test func beatsPerBar() { #expect(TimeSignature(beats: 7, unit: 8).beatsInQuarters == Rational(7, 2)) }
```
- [ ] **Bước 3:** Chạy `cd Packages/DrumKit && swift test --filter DrumCoreTests`. Kết quả mong đợi: FAIL (thiếu kiểu).
- [ ] **Bước 4:** Implement. Map MIDI theo GM, có thêm 37 → sideStick, 44 → hiHatPedal, 49/57 → crash, 48/50 → tom1, 45/47 → tom2, 41/43 → floorTom. Riêng Roland/Alesis có map khác: để `Voice.from` nhận thêm một bảng override `[UInt8: Voice]` (dùng ở Task 6).
- [ ] **Bước 5:** Chạy lại test → PASS.
- [ ] **Bước 6:** Commit `feat: scaffold DrumKit package, app target and core models`.

### Task 2: DSL bài tập + Timeline + nhãn đếm

DSL là định dạng text để người dùng (hoặc Claude) gõ bài tập. Mỗi ký tự là một ô lưới; `grid` là số ô trên một phách.

```
title: Single Paradiddle
time: 4/4
tempo: 60-120
grid: 4
HH: x-x-x-x-x-x-x-x-
SN: ----o-------o---
BD: o-------o-o-----
ST: RLRRLRLLRLRRLRLL
```
Ký hiệu: `x`/`o` = đánh thường, `X`/`O` = accent, `g` = ghost, `f` = flam, `d` = drag, `z` = buzz, `-` = nghỉ. Dòng `ST:` là sticking (R/L/F/-). Mã voice: `HH OH HP SN SS BD T1 T2 FT RD CR`. Bài nhiều ô nhịp viết nối dài, `|` là vạch nhịp và bị bỏ qua khi parse. Chùm ba dùng `grid: 3` (hoặc 6, 12).

**Files:** Create `ExerciseDSL.swift`, `Timeline.swift`, `Counting.swift`; Test `DSLTests.swift`, `TimelineTests.swift`, `CountingTests.swift`

**Interfaces – Produces:**
```swift
public enum ExerciseDSL {
  public static func parse(_ text: String) throws(DSLError) -> Exercise
  public static func serialize(_ exercise: Exercise, grid: Int) -> String
}
public enum DSLError: Error, Equatable { case missingHeader(String), unequalLineLengths, unknownVoice(String), badSymbol(Character, line: Int), lengthNotMultipleOfBar }
public struct TimedNote: Sendable, Hashable { public let index: Int; public let note: NoteEvent; public let time: TimeInterval } // giây tính từ phách 0
public struct Timeline: Sendable {
  public init(exercise: Exercise, bpm: Double, repeats: Int, countInBars: Int)
  public var notes: [TimedNote]          // đã sắp xếp; time đã cộng thêm phần count-in
  public var duration: TimeInterval
  public func beatTime(_ beat: Rational) -> TimeInterval
}
public enum CountMode: String, Codable, CaseIterable, Sendable { case quarters, eighths, sixteenths, triplets, sixteenthTriplets }
public enum Counting { public static func labels(mode: CountMode, beats: Int) -> [(position: Rational, label: String)] }
```

- [ ] **Bước 1: Viết test fail**
```swift
@Test func parsesParadiddle() throws {
  let ex = try ExerciseDSL.parse(paradiddleText)   // văn bản ví dụ ở trên
  #expect(ex.bars == 1); #expect(ex.timeSignature == .init(beats: 4, unit: 4))
  #expect(ex.notes.filter { $0.voice == .hiHat }.count == 8)
  #expect(ex.notes.first { $0.voice == .snare }!.position == Rational(1, 1))
  #expect(ex.suggestedTempo == 60...120)
}
@Test func accentGhostAndSticking() throws { /* "SN: Og--" grid 4 → accent ở 0, ghost ở 1/4; ST: "RL--" → hand gắn vào nốt */ }
@Test func unequalLinesRejected() { #expect(throws: DSLError.unequalLineLengths) { try ExerciseDSL.parse("time: 4/4\ngrid: 4\nSN: o---\nBD: o-") } }
@Test func roundTrip() throws { let ex = try ExerciseDSL.parse(paradiddleText); #expect(try ExerciseDSL.parse(ExerciseDSL.serialize(ex, grid: 4)).notes == ex.notes) }
@Test func timelineAt120() { let t = Timeline(exercise: ex, bpm: 120, repeats: 2, countInBars: 1)
  #expect(t.notes.first!.time == 2.0)          // count-in 1 ô nhịp = 4 phách × 0.5s
  #expect(t.notes.count == 2 * ex.notes.count); #expect(t.duration == 2.0 + 2 * 2.0) }
@Test func countingLabels() {
  #expect(Counting.labels(mode: .sixteenths, beats: 1).map(\.label) == ["1","e","&","a"])
  #expect(Counting.labels(mode: .triplets, beats: 2).map(\.label) == ["1","trip","let","2","trip","let"])
  #expect(Counting.labels(mode: .eighths, beats: 4).count == 8) }
@Test func sevenEight() throws { /* time: 7/8, grid tính theo nốt móc đơn → bars == 1, beatsInQuarters 7/2 */ }
```
- [ ] **Bước 2:** `swift test --filter DrumCoreTests` → FAIL.
- [ ] **Bước 3:** Implement. Với nhịp có `unit` = 8, `grid` tính theo nốt móc đơn. Phách trong `Rational` luôn tính theo nốt đen.
- [ ] **Bước 4:** Test → PASS.
- [ ] **Bước 5:** Commit `feat: exercise DSL, timeline and counting labels`.

---

## Mốc 2: Metronome và giọng đếm

### Task 3: ClickSchedule (thuần) + MetronomeEngine

**Files:** Create `DrumAudio/ClickSchedule.swift`, `HostClock.swift`, `MetronomeEngine.swift`, `CountVoiceBank.swift`; Test `DrumAudioTests/ClickScheduleTests.swift`

**Interfaces – Produces:**
```swift
public enum ClickKind: Sendable, Hashable { case downbeat, beat, subdivision, voice(String) } // voice("e") = âm tiết đếm
public struct ClickEvent: Sendable, Hashable { public let sampleTime: Int64; public let kind: ClickKind; public let bar: Int; public let level: Int; public let tone: LevelTone }
public enum ClickSound: String, Codable, CaseIterable, Sendable { case click, woodblock, cowbell, rimshot, hiHat, beep, voice } // voice = đọc âm tiết "1/e/&/a" ngay tại ô đó
public struct ClickSlot: Codable, Sendable, Equatable { public var level: Int /* 0 = tắt, 1…5 — 5 ô chồng */ ; public var sound: ClickSound? /* nil = dùng âm mặc định của mức */ }
/// Mỗi mức có ÂM + CAO ĐỘ + ĐỘ TO riêng để nghe là phân biệt được ngay (người dùng yêu cầu: "mức 1 khác các mức khác").
public struct LevelTone: Codable, Sendable, Equatable { public var sound: ClickSound; public var pitchHz: Double; public var gainDb: Double }
public enum ToneLadder {
  public static let `default`: [Int: LevelTone] = [
    5: .init(sound: .beep,      pitchHz: 1760, gainDb: 0),    // chuông cao — phách 1 / accent
    4: .init(sound: .click,     pitchHz: 1320, gainDb: -2),   // click cao — phách 2, 3, 4
    3: .init(sound: .cowbell,   pitchHz: 880,  gainDb: -5),   // cowbell — "&"
    2: .init(sound: .woodblock, pitchHz: 660,  gainDb: -9),   // woodblock trầm — "e"/"a" rõ
    1: .init(sound: .hiHat,     pitchHz: 0,    gainDb: -14),  // hi-hat khẽ — "e"/"a" nền
  ]
  public static func tone(for slot: ClickSlot, ladder: [Int: LevelTone]) -> LevelTone? // nil khi level 0; slot.sound ghi đè sound của mức
}
public struct ClickPattern: Codable, Sendable, Equatable {
  public var slots: [ClickSlot]                 // 1 phách chia làm slots.count ô: 4 = "1 e & a", 3 = "1 trip let", 2 = "1 &", 1 = "1"
  public static let quarter: ClickPattern       // [5]
  public static let eighths: ClickPattern       // [4,0,3,0] (click vào phách và &)
  public static let sixteenths: ClickPattern    // [4,1,3,1]
  public static let triplets: ClickPattern      // [4,2,2]
  public static let offbeat: ClickPattern       // [0,0,4,0] (chỉ click vào &)
}
public enum BeatSkip: String, Codable, CaseIterable, Sendable { case all, oneOnOneOff /* ●○●○ */, beatOneOnly /* ●○○○ */, backbeat /* ○●○● */ }
public struct MetronomeSettings: Sendable, Codable, Equatable {
  public var bpm: Double; public var timeSignature: TimeSignature
  public var pattern: ClickPattern
  public var accentBeatOne: Bool                // phách 1 dùng âm khác (cao hơn) và to hơn
  public var beatSkip: BeatSkip
  public var voiceCount: CountMode?             // giọng đếm chạy song song với click; nil = tắt
  public var gap: GapPattern?                   // tắt theo ô nhịp: GapPattern(playBars: 2, muteBars: 2)
  public var volume: Float; public var voiceVolume: Float; public var musicVolume: Float
}
public enum ClickSchedule {
  /// Các click có sampleTime nằm trong [from, to). Tuyệt đối không cộng dồn sai số: sample của click n = round(n * samplesPerTick).
  public static func events(settings: MetronomeSettings, sampleRate: Double, from: Int64, to: Int64) -> [ClickEvent]
}
@MainActor public final class MetronomeEngine: ObservableObject {
  public init(voiceBank: CountVoiceBank)
  public func start(settings: MetronomeSettings, at hostTime: TimeInterval?) throws
  public func stop()
  public func update(_ settings: MetronomeSettings)   // đổi tempo lúc đang chạy, áp dụng từ phách kế tiếp
  public private(set) var beatZeroHostTime: TimeInterval?   // dùng cho Timeline và HitMatcher
  @Published public private(set) var currentBeat: Int
  public var outputLatency: TimeInterval { get }
}
```

- [ ] **Bước 1: Viết test fail**
```swift
@Test func quartersAt120() { let e = ClickSchedule.events(settings: .init(bpm: 120, …quarters), sampleRate: 48000, from: 0, to: 96000)
  #expect(e.map(\.sampleTime) == [0, 24000, 48000, 72000]); #expect(e[0].kind == .downbeat) }
@Test func noDriftAfterTenMinutes() { // Review Focus #1
  let e = ClickSchedule.events(settings: .init(bpm: 137, …sixteenths), sampleRate: 48000, from: 0, to: 48000*600)
  #expect(e.last!.sampleTime == Int64((Double(e.count - 1) * 48000 * 60 / 137 / 4).rounded())) }
@Test func extremes() { #expect(!ClickSchedule.events(bpm 40 …).isEmpty); #expect(ClickSchedule.events(bpm 300, sixteenths, 1 giây).count == 20) }
@Test func windowBoundariesNoDupes() { /* nối [0,1000) với [1000,2000) phải ra đúng kết quả như gọi một lần [0,2000) */ }
@Test func gapMutesBars() { /* gap 1 chơi/1 im ở 4/4 → bar 1 không có event, bar 2 có */ }
@Test func backbeatOnly() { /* beatSkip .backbeat → chỉ có phách 2 và 4 */ }
@Test func clickPatternLevels() { // pattern [3,0,2,0] ở 60 BPM, 48 kHz
  let e = ClickSchedule.events(settings: .init(bpm: 60, pattern: .eighths, …), sampleRate: 48000, from: 0, to: 48000)
  #expect(e.map(\.sampleTime) == [0, 24000]); #expect(e.map(\.level) == [4, 3]) }
@Test func levelsHaveDistinctTones() { // mỗi mức 1…5 khác nhau về sound hoặc pitch
  let tones = (1...5).compactMap { ToneLadder.default[$0] }
  #expect(Set(tones.map { "\($0.sound)-\($0.pitchHz)" }).count == 5)
  #expect(tones.map(\.gainDb) == tones.map(\.gainDb).sorted(by: >)) }  // mức cao hơn thì to hơn
@Test func accentBeatOneUsesLevel5() { /* accentBeatOne + pattern quarter → phách 1 có tone mức 5, phách 2–4 mức 4 */ }
@Test func slotSoundOverridesLadder() { /* slot level 3, sound .rimshot → tone.sound == .rimshot, pitch/gain vẫn của mức 3 */ }
@Test func perSlotSound() { /* slot "&" chọn .rimshot → event ở 1/2 phách có tone.sound .rimshot */ }
@Test func beatSkipOneOnOneOff() { /* 4/4, pattern quarter → chỉ có phách 1 và 3 */ }
@Test func beatSkipBeatOneOnly() { /* chỉ có phách 1 */ }
@Test func tripletPatternTiming() { /* [4,2,2] ở 60 BPM → 0, 16000, 32000 */ }
@Test func voiceSyllables() { /* voiceCount .sixteenths → kinds .voice("1"), .voice("e"), .voice("&"), .voice("a") */ }
```
- [ ] **Bước 2:** `swift test --filter DrumAudioTests` → FAIL.
- [ ] **Bước 3:** Implement `ClickSchedule` (thuần). `MetronomeEngine` dùng một `AVAudioSourceNode` render callback: mỗi buffer gọi `ClickSchedule.events` cho đoạn sample của buffer đó rồi mix sample click hoặc giọng vào đúng frame offset. Cách này cho độ chính xác tới từng sample và không phụ thuộc vào timer. `CountVoiceBank` dùng `AVSpeechSynthesizer.write(_:toBufferCallback:)` render trước các âm tiết "one…twelve, e, and, a, trip, let" thành `AVAudioPCMBuffer` ở 48 kHz, cắt bỏ khoảng lặng đầu, rồi cache vào thư mục Caches. **Giọng đếm phải liền mạch** (người dùng phàn nàn rằng tiếng đếm bị giật ở âm "&"): mỗi âm tiết có fade-in 3 ms và fade-out 15 ms, không bao giờ bị cắt cụt; nếu âm tiết dài hơn ô thời gian của nó ở tempo hiện tại thì nén thời lượng (time-compress, giữ cao độ) cho vừa 90% ô; phách chính đọc to hơn "e & a" 4 dB để nghe ra nhịp điệu nói tự nhiên. Có thêm tùy chọn **tự ghi âm giọng mình** cho từng âm tiết trong Settings. Thêm test thuần `syllableFitsSlot`: hàm `CountVoiceBank.stretchFactor(syllableDuration: 0.35, slot: 60/90/4)` phải trả về < 1 và kết quả × 0.35 ≤ 0.9 × slot. Đặt `AVAudioSession` là `.playAndRecord` với `[.defaultToSpeaker, .allowBluetoothA2DP]` và `setPreferredIOBufferDuration(0.005)`.
  **Màn hình "Metronome & Âm thanh"** (sheet, theo mẫu Drum Journal):
  - Preset: Quarter / 8th / 16th / Triplet / Offbeat.
  - **Click Pattern:** mỗi ô "1 e & a" là một cột **5 ô chồng**; chạm vào ô thứ N để đặt mức N (chạm lại ô đang chọn để tắt), vuốt lên/xuống trên cột để tăng/giảm. Dưới mỗi cột hiện tên âm của mức đang chọn. Có trang **"Thang âm"** cho chỉnh âm, cao độ và độ to của từng mức 1…5, có nút nghe thử từng mức, và nút khôi phục `ToneLadder.default`. **Nhấn giữ** một cột để chọn âm thanh riêng cho ô đó (click, woodblock, cowbell, rimshot, hi-hat, beep, giọng đọc). Nhãn dưới cột sáng lên theo nhịp đang chạy.
  - Đổi số ô mỗi phách: 1 / 2 / 3 / 4 / 6.
  - Accent Beat 1.
  - Beat Skip: Tất cả / ●○●○ / ●○○○ / ○●○●.
  - Gap theo ô nhịp.
  - Giọng đếm (tắt hoặc chọn kiểu đếm).
  - Âm lượng riêng cho click, giọng đếm và nhạc nền.
  - Lưu được preset của mình.

  App tự tạo âm thanh (click, beep, woodblock, cowbell, hi-hat, rimshot) bằng DSP lúc chạy, theo `pitchHz` và `gainDb` của từng mức, không cần file mẫu. Accent Beat 1 = phách 1 tự lên mức 5.
- [ ] **Bước 4:** Test → PASS. Kiểm tra tay trên iPad thật: so với một metronome khác ở 60 và 200 BPM, nghe thấy không lệch.
- [ ] **Bước 5:** Commit `feat: sample-accurate metronome with spoken counting`.

### Task 4: TempoTrainer (tăng tốc dần, speed trainer)

**Files:** Create `DrumLibrary/TempoTrainer.swift`; Test `DrumLibraryTests/TempoTrainerTests.swift`

**Interfaces – Produces:**
```swift
public struct TempoRamp: Codable, Sendable, Equatable { public var start: Double; public var target: Double; public var step: Double; public var everyBars: Int; public var requireAccuracy: Double? } // ví dụ tăng +4 BPM sau mỗi 4 ô nhịp nếu ≥ 90%
public struct TempoTrainer: Sendable { public init(_ ramp: TempoRamp); public mutating func barCompleted(accuracy: Double?) -> Double /* bpm cho ô nhịp tiếp theo */ }
```
- [ ] **Bước 1: Test:** `ramp(60→80, +5, mỗi 2 ô)`: sau 2 ô ra 65, sau 8 ô ra 80, sau 20 ô vẫn 80. Khi có `requireAccuracy 0.9` và accuracy 0.8 thì giữ nguyên tempo.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement. **Bước 4:** PASS.
- [ ] **Bước 5:** Commit `feat: tempo ramp trainer`.

---

## Mốc 3: Khuông nhạc chạy theo tempo

### Task 5: NotationView + PracticeView cơ bản

**Files:** Create `DrumCore/NotationLayout.swift` (thuần, test được), `App/.../Practice/NotationView.swift`, `PracticeView.swift`, `PracticeViewModel.swift`; Test `DrumCoreTests/NotationLayoutTests.swift`

**Interfaces – Produces:**
```swift
public struct NotationLayout: Sendable {
  public init(exercise: Exercise, barWidth: Double, barsPerLine: Int, staffSpacing: Double)
  public struct Glyph: Sendable, Hashable { public let noteIndex: Int; public let x: Double; public let line: Int; public let staffStep: Int; public let xHead: Bool; public let accent: Bool; public let ghost: Bool; public let hand: Hand? }
  public var glyphs: [Glyph]
  public var beams: [(line: Int, fromX: Double, toX: Double, level: Int)]  // level 1 = móc đơn, 2 = móc kép, 3 = móc ba
  public func playheadX(atBeat beat: Rational) -> (line: Int, x: Double)  // nội suy tuyến tính trong ô nhịp
}
@MainActor final class PracticeViewModel: ObservableObject {
  @Published var exercise: Exercise; @Published var settings: MetronomeSettings; @Published var mode: InputMode // .pad, .eDrum, .listenOnly
  @Published var results: [Int: NoteResult]   // index nốt → kết quả (Task 7)
  func play(); func stop()
}
```
- [ ] **Bước 1: Test:** paradiddle với barWidth 400 thì glyph đầu tiên x > 0, các nốt cùng vị trí (HH + BD ở phách 0) có cùng x, `playheadX(Rational(2,1))` nằm giữa ô nhịp; bài 4 ô nhịp với `barsPerLine 2` thì glyph cuối có `line == 1`; nốt 16th có beam level 2; nốt ghost được ghi nhận để vẽ ngoặc đơn.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement layout thuần, sau đó `NotationView` vẽ bằng SwiftUI `Canvas`: 5 dòng kẻ, khóa bộ gõ, nốt (đặc hoặc x), đuôi, beam, dấu `>`, ghost trong ngoặc, chữ R/L dưới nốt. Playhead là thanh dọc mờ di chuyển bằng `TimelineView(.animation)`, vị trí tính từ `hostTime - beatZeroHostTime - outputLatency`. Nốt đang đánh sáng lên. Bật tùy chọn thì hiện nhãn voice (HI-HAT/SNARE) ở lần đầu một voice xuất hiện, giống video tham khảo. Hai kiểu hiển thị: **trang tĩnh** (playhead chạy, xuống dòng) và **cuộn ngang** (khuông trôi, playhead đứng yên).
- [ ] **Bước 4:** PASS. Kiểm tra tay trên simulator: ở 60 và 180 BPM, playhead trùng với tiếng click.
- [ ] **Bước 5:** Thêm **dải R/L** dưới khuông nhạc, giống Drum Journal: làn R ở trên, làn L ở dưới, trục giữa có nhãn đếm theo `Counting.labels`, vạch đứng cố định, các nốt trôi từ phải sang trái. Mỗi nốt là một vạch đứng, có màu theo kết quả ở Task 7. Nút **FLIP** đổi mọi `Hand.right` ↔ `.left` (có test thuần `Exercise.flippedHands()`). Thời lượng bài chọn được 30 giây / 1 / 2 / 5 phút; `repeats` tính bằng thời lượng chia cho độ dài một vòng bài rồi làm tròn lên.
- [ ] **Bước 6:** Thanh điều khiển trong PracticeView gồm: BPM (slider ±1 và tap tempo), chọn nhịp click, chọn kiểu đếm giọng, số ô count-in, lặp lại, gap click, tempo ramp, chọn chế độ Pad / Trống điện.
- [ ] **Bước 7:** Commit `feat: animated drum notation with playhead`.

---

## Mốc 4: Nghe người chơi

### Task 6: Nguồn cú đánh: MIDI + micro + hiệu chỉnh độ trễ

**Files:** Create `DrumAnalysis/Hit.swift`, `OnsetDetector.swift`, `LatencyCalibrator.swift`, `DrumAudio/MIDIHitSource.swift`, `MicOnsetSource.swift`, `App/.../Settings/CalibrationView.swift`; Test `DrumAnalysisTests/OnsetDetectorTests.swift`, `LatencyCalibratorTests.swift`

**Interfaces – Produces:**
```swift
public struct Hit: Sendable, Hashable { public let time: TimeInterval /* host time, đã trừ độ trễ */; public let voice: Voice? /* nil khi là micro */; public let velocity: Double /* 0...1 */ }
public protocol HitSource: AnyObject, Sendable { var hits: AsyncStream<Hit> { get } ; func start() throws; func stop() }
public struct OnsetDetector: Sendable {
  public init(sampleRate: Double, threshold: Double = 0.15, minInterval: TimeInterval = 0.025)
  /// frames: mono Float; startTime: thời điểm (giây) của frame 0. Trả về các onset phát hiện được trong khối này; giữ trạng thái giữa các khối.
  public mutating func process(_ frames: [Float], startTime: TimeInterval) -> [(time: TimeInterval, strength: Double)]
  public var suppressWindows: [ClosedRange<TimeInterval>] // chặn tiếng metronome lọt vào micro
}
public enum LatencyCalibrator { public static func estimate(expected: [TimeInterval], detected: [TimeInterval]) -> TimeInterval? } // trung vị độ lệch; nil nếu < 8 cặp hoặc độ phân tán > 15 ms
```
- [ ] **Bước 1: Test**
```swift
@Test func detectsImpulses() { // nhiễu trắng biên độ 0.01 + 4 xung tắt dần tại 0.5/1.0/1.5/2.0 s
  var d = OnsetDetector(sampleRate: 48000); let on = feedInChunks(of: 256)   // đưa vào theo từng khối 256 frame
  #expect(on.count == 4); #expect(on.allSatisfy { abs($0.time - nearestExpected) < 0.003 }) }
@Test func flamNotDoubleCountedButFastRollIs() { /* 2 xung cách nhau 10 ms → 1 onset; cách 40 ms → 2 onset */ }
@Test func suppressWindowBlocksClick() { /* Review Focus #2: xung nằm trong suppressWindow thì bị bỏ */ }
@Test func silenceGivesNothing() {}
@Test func calibratorMedian() { #expect(abs(LatencyCalibrator.estimate(expected: e, detected: e.map{$0+0.042})! - 0.042) < 0.001) }
@Test func calibratorRejectsNoise() { /* độ lệch ngẫu nhiên ±50 ms → nil */ }
```
- [ ] **Bước 2:** FAIL. **Bước 3:** `OnsetDetector`: đường bao năng lượng theo cửa sổ 64 sample, kết hợp high-pass đơn giản (lọc bớt tiếng ồn nền và tiếng bass) và ngưỡng thích nghi (trung vị động × hệ số + threshold), có thời gian chết `minInterval`. Lấy thời điểm onset là sample đầu tiên vượt ngưỡng. `MicOnsetSource`: `installTap` buffer 256 trên input node, thời gian = `AVAudioTime.seconds(forHostTime:)` của buffer, trừ `inputLatency` và độ trễ đã hiệu chỉnh. `MIDIHitSource`: `MIDIInputPortCreateWithProtocol` (MIDI 1.0), nhận Note On có velocity > 0, timestamp là host time của gói, kết nối mọi nguồn (USB và Bluetooth MIDI qua `CABTMIDICentralViewController`), cho phép override map nốt. **CalibrationView:** phát 16 click và yêu cầu gõ theo, hoặc ở chế độ pad đặt iPad cạnh loa để micro tự bắt click; lưu offset riêng cho từng chế độ.
- [ ] **Bước 4:** PASS. Kiểm tra tay: gõ pad cạnh iPad, onset hiện ra trong log debug.
- [ ] **Bước 5:** Commit `feat: MIDI and microphone hit detection with latency calibration`.

### Task 7: HitMatcher + thống kê + phản hồi sớm/trễ trực tiếp

**Files:** Create `DrumAnalysis/HitMatcher.swift`, `SessionStats.swift`, `App/.../Practice/TimingStrip.swift`; Modify `PracticeViewModel.swift`, `NotationView.swift`; Test `HitMatcherTests.swift`, `SessionStatsTests.swift`

**Interfaces – Produces:**
```swift
public enum NoteResult: Sendable, Hashable { case hit(offset: TimeInterval, velocity: Double), wrongVoice(offset: TimeInterval, played: Voice), missed }
public enum Grade: Sendable, Hashable { case good /* xanh lá */, early /* cam, vạch đặt trước nốt */, late /* cam, vạch đặt sau nốt */, missed /* đỏ */ }
public struct ScoringRules: Codable, Sendable, Equatable { public var goodWindow: TimeInterval = 0.030; public var extraHitPenalty: Double = 0.5
  public func grade(_ r: NoteResult) -> Grade         // .wrongVoice được chấm như .early hoặc .late theo offset
  public func score(_ results: [NoteResult], totalNotes: Int, extraHits: Int) -> Double } // 0...100; nốt chưa có kết quả tính là missed
public struct HitMatcher: Sendable {
  public init(expected: [TimedNote], beatZero: TimeInterval, window: TimeInterval) // window = min(0.1, 0.45 × khoảng cách nhỏ nhất giữa hai nốt)
  public mutating func consume(_ hit: Hit) -> (noteIndex: Int, result: NoteResult)?  // nil = cú đánh thừa
  public mutating func expire(upTo now: TimeInterval) -> [(Int, NoteResult)]        // trả về các nốt đã quá hạn mà chưa được đánh → .missed
  public private(set) var extraHits: [Hit]
}
public struct SessionStats: Codable, Sendable, Equatable {
  public init(results: [Int: NoteResult], notes: [TimedNote], extraHits: Int)
  public let accuracy: Double            // tỷ lệ nốt .hit với |offset| ≤ 30 ms
  public let meanOffsetMs: Double        // âm = sớm, dương = trễ
  public let stdDevMs: Double
  public let missed: Int; public let wrongVoice: Int; public let extra: Int
  public let byBeatPosition: [String: Double]  // "1","e","&","a" → độ lệch trung bình (ms), để tìm điểm yếu
  public let byVoice: [Voice: Double]
  public let velocityCV: Double?               // độ đều lực đánh (chỉ có với MIDI)
}
```
- [ ] **Bước 1: Test**
```swift
@Test func earlyAndLate() { /* nốt ở 1.0 và 1.5; hit 0.98 → offset -0.02; hit 1.53 → +0.03 */ }
@Test func extraHitDoesNotStealNext() { /* Review Focus #3: nốt ở 1.0 và 1.25, window 0.1; hit ở 1.0 rồi 1.1 → hit thứ hai bị coi là thừa, nốt 1.25 vẫn đang chờ */ }
@Test func missedOnExpire() { /* nốt 1.0, không có hit, expire(1.2) → .missed */ }
@Test func wrongVoiceWithMIDI() { /* nốt snare, hit voice .tom1 → .wrongVoice */ }
@Test func micHitMatchesAnyVoiceAtSameTime() { /* HH + BD cùng thời điểm, chỉ một hit micro (voice nil) → cả hai nốt cùng thời điểm đó tính là hit */ }
@Test func newRunResets() { /* Review Focus #4: matcher mới tạo với beatZero mới; hit có time < beatZero bị bỏ qua, không bị ghép */ }
@Test func gradeColors() { let r = ScoringRules()
  #expect(r.grade(.hit(offset: 0.029, velocity: 1)) == .good); #expect(r.grade(.hit(offset: -0.031, velocity: 1)) == .early)
  #expect(r.grade(.hit(offset: 0.05, velocity: 1)) == .late); #expect(r.grade(.missed) == .missed) }
@Test func scorePercent() { let r = ScoringRules()
  // 8 xanh + 1 cam + 1 đỏ trên 10 nốt → (8 + 0.5) / 10 = 85%
  #expect(r.score(eightGoodOneLateOneMissed, totalNotes: 10, extraHits: 0) == 85)
  #expect(r.score(allGood10, totalNotes: 10, extraHits: 4) == 80)       // 10 − 4×0.5 = 8
  #expect(r.score([], totalNotes: 10, extraHits: 30) == 0) }            // không bao giờ âm
@Test func stats() { /* offset -10, +10, +40 ms, 1 missed → accuracy 2/4, mean +13.3, missed 1 */ }
```
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement. Khi ở chế độ micro, coi các nốt có cùng `time` là một "cụm" và một hit ghép với cả cụm. Trong PracticeViewModel, mỗi lần bấm Play tạo `HitMatcher` mới, gọi `expire` theo từng frame. **Phản hồi trực tiếp** (cả trên khuông nhạc lẫn dải R/L), theo `ScoringRules.grade`:
- **Xanh lá:** đúng.
- **Cam:** một vạch cam nằm **bên trái nốt** nếu sớm, **bên phải** nếu muộn; khoảng cách tới nốt tỉ lệ với số ms lệch; có kèm số "−42" hoặc "+38".
- **Đỏ:** trượt.

**Lưu lịch sử ngay từ task này:** mỗi lần chơi (kể cả khi bấm dừng sớm) lưu thành một `PracticeSession` bằng SwiftData. Bản ghi gồm: thời điểm, exerciseId và tên bài, BPM, thời lượng, chế độ pad/e-drum, mức độ khó, score, `SessionStats`. Lưu thêm **thống kê theo tay dự kiến**: micro không biết tay nào đánh, nhưng bài tập có sticking R/L, nên gán được độ lệch của từng nốt cho tay "lẽ ra phải đánh". Thêm `byHand: [Hand: Double]` vào `SessionStats`. Model `PracticeSession` được tạo ở task này; Task 10 chỉ thêm field `assessment`.

Trong lúc chơi hiện **Score %** chạy trực tiếp. Màn hình kết quả cuối bài gồm: **% hoàn thành** (chữ lớn), số nốt xanh / cam / đỏ, xu hướng chung ("hay đánh sớm 18 ms"), và vị trí đếm yếu nhất. `TimingStrip` là dải ngang có vạch 0 ở giữa và các chấm của 16 cú đánh gần nhất, để thấy ngay mình đang có xu hướng nhanh hay chậm. Cuối mỗi lần chơi hiện bảng tóm tắt `SessionStats`.
- [ ] **Bước 4:** PASS.
- [ ] **Bước 5:** Commit `feat: hit matching with live early/late feedback`.

### Task 7A: Count Coach – luyện đếm thành tiếng

Mục đích là sửa tật đếm giật ở "&". Có bốn giai đoạn: (1) app đếm mẫu, người dùng nghe; (2) đếm cùng app; (3) giọng app nhỏ dần rồi tắt, chỉ còn click; (4) click cũng tắt (gap), người dùng tự đếm. Micro bắt thời điểm từng âm tiết người dùng nói và chấm điểm như một cú đánh.

**Files:** Create `DrumAnalysis/SyllableOnsetDetector.swift`, `App/.../Practice/CountCoachView.swift`; Test `SyllableOnsetTests.swift`

**Interfaces – Produces:**
```swift
public struct SyllableOnsetDetector: Sendable {   // dùng lại OnsetDetector nhưng lọc dải tần giọng nói 150–3000 Hz, minInterval 0.08 s
  public init(sampleRate: Double)
  public mutating func process(_ frames: [Float], startTime: TimeInterval) -> [TimeInterval]
}
public struct CountEvenness: Sendable, Equatable { public let offsetsByLabel: [String: Double] /* "&" → +35 ms */ ; public let gapRatioStdDev: Double /* độ đều giữa các âm tiết */ }
```
- [ ] **Bước 1: Test:** chuỗi tổng hợp gồm 8 "âm tiết" (sóng sin 300 Hz kèm đường bao 120 ms) cách đều 0.333 s → phát hiện đủ 8 onset, sai số ≤ 10 ms; tiếng click 4 kHz rất ngắn bị lọc bỏ; `CountEvenness` khi các âm "&" trễ đều 40 ms phải ra `offsetsByLabel["&"] ≈ +40`.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement. Dùng `HitMatcher` với `Timeline` gồm các nốt ở mọi vị trí đếm. UI hiện dãy nhãn "1 & 2 & 3 & 4 &" và tô màu từng nhãn theo sớm/trễ, kèm nhận xét kiểu "Bạn nói '&' trễ trung bình 40 ms → nghĩ '&' nằm ĐÚNG giữa hai phách". Bắt buộc dùng tai nghe ở giai đoạn 2 và 3.
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: count coach for spoken counting`.

---

## Mốc 5: Thư viện bài tập

### Task 8: Generator kiểu Stick Control + giáo trình Grade 8 + Thư viện

**Files:** Create `DrumLibrary/StickingGenerator.swift`, `Grade8Curriculum.swift`, `App/Models/StoredExercise.swift`, `App/.../Library/LibraryView.swift`, `ExerciseEditorView.swift`; Test `StickingGeneratorTests.swift`, `Grade8CurriculumTests.swift`

**Interfaces – Produces:**
```swift
public enum StickingGenerator {
  /// Mọi tổ hợp R/L dài `length` (ví dụ 8 nốt móc đơn = 256 tổ hợp), sắp xếp theo độ "dễ" (số lần đổi tay tăng dần), có thể lọc chỉ lấy tổ hợp cân bằng tay.
  public static func singleBeat(length: Int, subdivision: Int, voice: Voice = .snare, balancedOnly: Bool) -> [Exercise]
  public static func triplets(length: Int) -> [Exercise]
  public static func withAccents(_ base: Exercise, accentEvery: Int, offset: Int) -> Exercise
  public static func orchestrate(_ base: Exercise, rightHand: Voice, leftHand: Voice) -> Exercise // R → hi-hat/tom, L → snare…
  public static func random(seed: UInt64, bars: Int, subdivision: Int, rests: Bool) -> Exercise // dùng cho luyện đọc bản nhạc (sight reading)
}
public struct CurriculumUnit: Sendable, Identifiable { public let id: String; public let title: String; public let skill: String; public let exercises: [String /* DSL */]; public let targetTempo: Int }
public enum Grade8Curriculum { public static let units: [CurriculumUnit] }
```
- [ ] **Bước 1: Test:** `singleBeat(length: 8, …balancedOnly: false).count == 256`; phần tử đầu là `RLRLRLRL` hoặc `RRRRRRRR` theo đúng quy tắc sắp xếp đã chọn; không có hai bài trùng nhau; với `balancedOnly` thì mọi bài có 4 R và 4 L; `random(seed: 1)` gọi hai lần ra kết quả giống nhau; **mọi chuỗi DSL trong `Grade8Curriculum.units` parse được** và có `suggestedTempo` hợp lệ.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement. Giáo trình Grade 8 (bài do app tự soạn, không chép sách), mỗi unit 3–6 bài, xếp từ dễ đến khó:
  1. Rudiments: single/double stroke, paradiddle và các biến thể, flam (flam tap, flamacue), drag, 6-stroke roll, 5/7/9-stroke roll
  2. Groove 16th: hi-hat một tay và hai tay, ghost note trên snare
  3. Linear groove và fill
  4. Double kick/ostinato (kick dùng `F`)
  5. Chùm ba và sextuplet; shuffle và half-time shuffle
  6. Nhịp lẻ 5/4, 7/8, 12/8
  7. Fill qua nhiều tom, displacement, metric modulation đơn giản
  8. Đọc nhạc: dùng `random` ở các mức độ khó khác nhau

  Thư viện lưu bằng SwiftData (`StoredExercise` chứa chuỗi DSL, nguồn, tag, mức độ yêu thích). `ExerciseEditorView` là ô soạn DSL có xem trước khuông nhạc ngay khi gõ và báo lỗi parse theo số dòng.
- [ ] **Bước 4:** PASS.
- [ ] **Bước 5:** Commit `feat: sticking generator, Grade 8 curriculum and exercise library`.

---

## Mốc 6: Claude AI

### Task 9: ClaudeClient + nhập bài từ PDF

**Files:** Create `DrumAI/ClaudeClient.swift`, `PageTranscriber.swift`, `App/.../Library/PDFImportView.swift`, `App/.../Settings/SettingsView.swift` (API key lưu Keychain, chọn model); Test `DrumAITests/ClaudeClientTests.swift`, `PageTranscriberTests.swift`

**Interfaces – Produces:**
```swift
public protocol HTTPTransport: Sendable { func send(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) } // fake trong test
public struct ClaudeClient: Sendable {
  public init(apiKey: String, model: String, transport: HTTPTransport)
  /// Gọi Messages API với structured outputs (output_config.format json_schema), decode text JSON trả về thành T. Tham số `webSearch: Bool` bật server tool web_search_20260209.
  public func structured<T: Decodable & Sendable>(system: String, content: [ContentBlock], schema: JSONValue, as: T.Type, effort: Effort, webSearch: Bool, maxTokens: Int) async throws(ClaudeError) -> T
}
public enum ContentBlock: Sendable { case text(String), imagePNG(Data) }
public enum ClaudeError: Error, Equatable { case missingKey, http(Int, String), refused(String?), decoding(String), network(String) }
public enum PageTranscriber { public static func transcribe(pagePNG: Data, client: ClaudeClient) async throws(ClaudeError) -> [String /* DSL */] }
```
- [ ] **Bước 1: Test** (fake transport):
  - request có header `x-api-key`, `anthropic-version: 2023-06-01`, body có `model`, `output_config.format.type == "json_schema"`, `thinking.type == "adaptive"`, `fallbacks == "default"`, **không có** `tool_choice`; response có `stop_reason: "refusal"` → `.refused`;
  - response mẫu có text là JSON hợp lệ thì decode thành T;
  - status 401 → `.http(401, …)`; JSON không khớp schema → `.decoding`;
  - `PageTranscriber` loại bỏ những chuỗi DSL mà `ExerciseDSL.parse` báo lỗi.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement. `PDFImportView`: chọn file PDF (UIDocumentPicker), render trang bằng PDFKit ra PNG rộng 1600 px, gửi kèm prompt hướng dẫn chuyển từng bài trên trang sang DSL (có mô tả ngữ pháp DSL ở Task 2 và ví dụ). Hiện từng bài đọc được kèm khuông nhạc xem trước để người dùng sửa hoặc lưu. Ghi rõ trong UI: "Chỉ dùng với sách bạn sở hữu; dữ liệu chỉ lưu trên máy này."
- [ ] **Bước 4:** PASS. Kiểm tra tay với một trang Stick Control của người dùng.
- [ ] **Bước 5:** Commit `feat: Claude client and PDF page transcription`.

### Task 10: Đánh giá trình độ theo Rockschool

**Files:** Create `DrumAI/AssessmentRequest.swift`, `App/Models/PracticeSession.swift`, `App/.../Practice/AssessmentView.swift`; Test `DrumAITests/AssessmentTests.swift`

**Interfaces – Produces:**
```swift
public struct AssessmentInput: Codable, Sendable { public let exerciseTitle: String; public let skill: String; public let bpm: Double; public let targetBpm: Int; public let stats: SessionStats; public let recentHistory: [SessionStats] /* tối đa 10 */ ; public let mode: String }
public struct Assessment: Codable, Sendable, Equatable {
  public let estimatedGrade: Int          // 1...8
  public let band: String                 // "Below Pass" | "Pass" | "Merit" | "Distinction"
  public let timingComment: String; public let strengths: [String]; public let weaknesses: [String]
  public let nextSteps: [String]; public let suggestedTempo: Int
}
public enum AssessmentRequest {
  public static let systemPrompt: String
  public static func run(_ input: AssessmentInput, client: ClaudeClient) async throws(ClaudeError) -> Assessment
  public static func localFallback(_ input: AssessmentInput) -> Assessment // khi không có key hoặc lỗi: chấm theo luật đơn giản
}
```
- [ ] **Bước 1: Test:** response hợp lệ → `Assessment` đúng giá trị; JSON thiếu field → `.decoding`; **Review Focus #5:** transport ném lỗi mạng → caller vẫn có `localFallback` và kết quả cục bộ giữ nguyên; `localFallback` với accuracy 0.95, std 8 ms, đủ tempo → band "Distinction"; với accuracy 0.5 → "Below Pass"; `estimatedGrade` bị giới hạn trong 1...8.
- [ ] **Bước 2:** FAIL. **Bước 3:** System prompt mô tả: người chơi hướng tới Rockschool Grade 8; các mức chấm (Pass 60%, Merit 74%, Distinction 90% — **phải đối chiếu lại với syllabus Rockschool hiện hành trước khi ship**); những gì giám khảo nghe (độ chính xác nhịp, độ ổn định tempo, động lực/accent, sự trôi chảy); và chỉ dựa trên số liệu đo được, không bịa. Lưu mỗi lần chơi vào `PracticeSession` (SwiftData) cùng stats và assessment. Khi lỗi thì hiện banner "Không kết nối được Claude — đang dùng đánh giá cục bộ".
- [ ] **Bước 4:** PASS.
- [ ] **Bước 5:** Commit `feat: Rockschool-style assessment via Claude with local fallback`.

### Task 10A: Danh sách bài test level

Người dùng chưa biết trình độ của mình. Có **8 level**, mỗi level có một **danh sách bài test** cố định (3–5 bài, lấy từ `Grade8Curriculum`), mỗi bài có tempo, thời lượng và ngưỡng ghép cố định.

Quy tắc:
- **Một bài test được tính là đạt khi score > 90%** (đúng 90.0% thì chưa đạt).
- **Đạt level khi mọi bài test của level đó đều đạt.** Kết quả lấy lần chơi tốt nhất của từng bài, nên có thể đạt từng bài ở những buổi khác nhau.
- **Level hiện tại** là level cao nhất mà mọi level bên dưới nó cũng đã đạt.
- Level kế tiếp được mở khóa khi đạt level trước. Riêng lần đầu, người dùng được thử bất kỳ level nào để tìm điểm bắt đầu.
- Chế độ test khóa tempo và ngưỡng (không đổi BPM, không FLIP, không chỉnh Dễ/Khó).

**Files:** Create `DrumLibrary/LevelTests.swift`, `App/Models/LevelAttempt.swift`, `App/.../Progress/LevelListView.swift`; Test `LevelTestsTests.swift`

**Interfaces – Produces:**
```swift
public struct LevelTestItem: Sendable, Identifiable { public let id: String; public let dsl: String; public let bpm: Double; public let duration: TimeInterval; public let skill: String }
public struct Level: Sendable, Identifiable { public let id: Int /* 1...8 */; public let title: String; public let tests: [LevelTestItem] }
public enum LevelCatalog { public static let levels: [Level]; public static let passMark: Double = 90 /* phải > */ }
public struct LevelProgress: Sendable {
  public init(bestScores: [String: Double])            // id bài test → % cao nhất
  public func isPassed(_ test: LevelTestItem) -> Bool  // bestScore > 90
  public func isPassed(_ level: Level) -> Bool
  public var currentLevel: Int                         // 0 nếu chưa đạt level nào
  public func isUnlocked(_ level: Level) -> Bool
}
```
- [ ] **Bước 1: Test:**
  - score 90.0 → chưa đạt; 90.1 → đạt.
  - Level 1 có 3 bài, đạt 2 bài → level chưa đạt; đạt đủ 3 bài → đạt.
  - Đạt level 1 và 3 nhưng chưa đạt level 2 → `currentLevel == 1`.
  - Chưa có lần chơi nào → `currentLevel == 0` và mọi level đều thử được.
  - Mọi `dsl` trong `LevelCatalog` parse được; level N+1 không có bài nào có tempo × độ chia nhỏ hơn level N (độ khó không giảm).
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement. Gợi ý nội dung mỗi level (bài do app tự soạn; tempo tính theo nốt đen):

  | Level | Nội dung test | Tempo |
  |---|---|---|
  | 1 | Nốt đen, móc đơn, single stroke | 60–70 |
  | 2 | Double stroke, sticking 8 nốt kiểu Stick Control | 70 |
  | 3 | Móc kép, paradiddle, accent | 70–80 |
  | 4 | Groove 8th/16th, flam | 80 |
  | 5 | Chùm ba, shuffle, ghost note | 85–90 |
  | 6 | Linear, roll 5/7/9 nét, fill qua tom | 90–100 |
  | 7 | Nhịp lẻ 7/8, 5/4, sextuplet | 100 |
  | 8 | Tổng hợp mức Grade 8: 16th 110+, displacement, đọc nhạc | 110–120 |

  `LevelListView` liệt kê 8 level. Mỗi level có trạng thái 🔒 / đang làm / ✅, và mỗi bài test hiện % tốt nhất cùng dấu ✓ khi > 90%. Mỗi lần chơi lưu một `LevelAttempt` (SwiftData). Đạt level thì có màn hình chúc mừng. Có thể bấm "Nhờ Claude nhận xét" để gửi `AssessmentRequest` và nhận **lộ trình 4 tuần** cho level kế tiếp ("Hôm nay tập gì").
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: level test list with >90% pass rule`.

---

## Mốc 7: Tiến độ

### Task 11: Màn hình Tiến độ + nhật ký tập

**Files:** Create `App/.../Progress/ProgressView.swift`, `DrumAnalysis/ProgressSummary.swift`; Test `ProgressSummaryTests.swift`

**Interfaces – Produces:**
```swift
public struct ProgressSummary: Sendable { public init(sessions: [(date: Date, exerciseId: UUID, bpm: Double, stats: SessionStats)], calendar: Calendar)
  public var streakDays: Int; public var minutesThisWeek: Double
  public func bestCleanTempo(exerciseId: UUID, minAccuracy: Double) -> Double?   // tempo cao nhất mà vẫn đạt độ chính xác yêu cầu
  public var weakestBeatPosition: String? }
```
- [ ] **Bước 1: Test:** tập 3 ngày liên tiếp (tính cả hôm nay) → streak 3; bỏ một ngày → streak reset; `bestCleanTempo` bỏ qua các lần chơi có accuracy dưới ngưỡng.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement. Dùng Swift Charts vẽ: tempo sạch theo thời gian cho từng bài, độ lệch trung bình (ms) theo tuần, heatmap sớm/trễ theo vị trí "1 e & a", và chuỗi ngày tập.
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: progress tracking and charts`.

---

## Mốc 8: Giáo viên AI

Đây là "người thầy" của người dùng. Nguyên tắc:
1. **Lịch sử không bao giờ mất.** Lưu trên máy, kèm backup ra file.
2. **Gửi bản tóm tắt chứ không gửi dữ liệu thô.** Lịch sử nhiều tháng được nén thành một bản tóm tắt vài KB trước khi gửi Claude.
3. **Thầy có trí nhớ.** Một "hồ sơ học viên" lưu mục tiêu, các lời khuyên đã đưa, và người dùng đã làm theo hay chưa.
4. **Link phải là thật.** Không để AI bịa link YouTube.

### Task 13: Lịch sử dài hạn – tóm tắt + backup + nhật ký

**Files:** Create `DrumAnalysis/HistorySummarizer.swift`, `App/Models/JournalEntry.swift`, `App/.../Progress/HistoryView.swift`, `App/Services/BackupService.swift`; Test `HistorySummarizerTests.swift`, `App/…/BackupTests` (unit test target của app)

**Interfaces – Produces:**
```swift
public struct SessionRecord: Codable, Sendable { public let date: Date; public let exerciseId: String; public let title: String; public let skill: String; public let bpm: Double; public let minutes: Double; public let score: Double; public let stats: SessionStats; public let isLevelTest: Bool }
public struct HistoryDigest: Codable, Sendable, Equatable {
  public let totalMinutes: Double; public let daysPracticed: Int; public let firstDate: Date?; public let currentLevel: Int
  public let weekly: [WeekRollup]          // tối đa 26 tuần gần nhất: phút tập, score trung bình, độ lệch trung bình
  public let perExercise: [ExerciseTrend]  // tempo sạch tốt nhất (score > 90) theo từng tháng, số lần tập, lần tập cuối
  public let recurringWeaknesses: [String] // ví dụ "'&' trễ +28 ms trong 6/8 tuần", "tay L sớm −20 ms"
  public let last7Days: [SessionRecord]    // chi tiết nhất cho tuần gần đây
  public let journal: [String]             // ghi chú tự viết trong 30 ngày gần nhất
}
public enum HistorySummarizer { public static func digest(_ records: [SessionRecord], journal: [(Date, String)], currentLevel: Int, now: Date, calendar: Calendar) -> HistoryDigest }
```
- [ ] **Bước 1: Test:**
  - 2 năm dữ liệu giả (≈ 1500 buổi): `weekly.count == 26`, và JSON của digest nhỏ hơn 24 KB.
  - Một điểm yếu "&" trễ +30 ms xuất hiện trong 6/8 tuần → có trong `recurringWeaknesses`. Trễ 1 tuần thì không tính.
  - Chưa có lịch sử → digest rỗng, không crash.
  - `perExercise` chỉ lấy tempo của các lần có score > 90.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement.
  - **Nhật ký:** sau mỗi buổi tập có ô ghi chú tùy chọn (cảm nhận, đau mỏi, chỗ khó).
  - **HistoryView:** lịch tập dạng calendar, bấm vào một ngày để xem các lần chơi.
  - **Backup:** xuất toàn bộ lịch sử ra một file JSON (`DrumCoach-backup-YYYY-MM-DD.json`) vào Files hoặc iCloud Drive, và nhập lại được. Mỗi Chủ nhật tự backup vào thư mục Documents của app (bật trong Files). Test round-trip: xuất rồi nhập vào store rỗng phải ra cùng số bản ghi và cùng score.
- [ ] **Bước 3b: Tổng kết giai đoạn (người dùng muốn "sau 3 tháng review lại xem mình đã đi tới đâu"):**

  Thêm:
  ```swift
  public struct PeriodReview: Codable, Sendable, Equatable {
    public let from: Date; public let to: Date; public let totalHours: Double; public let daysPracticed: Int; public let longestStreak: Int
    public let levelStart: Int; public let levelEnd: Int; public let levelsPassed: [(Int, Date)]   // mốc đạt từng level
    public let exerciseDeltas: [(title: String, cleanBpmStart: Double?, cleanBpmEnd: Double?)]  // tempo sạch (score > 90) ở 2 tuần đầu so với 2 tuần cuối
    public let offsetStartMs: Double; public let offsetEndMs: Double; public let scoreStart: Double; public let scoreEnd: Double
    public let fixedWeaknesses: [String]; public let remainingWeaknesses: [String]
  }
  public enum HistorySummarizer { public static func periodReview(_ records: [SessionRecord], levelHistory: [(Int, Date)], from: Date, to: Date, calendar: Calendar) -> PeriodReview }
  ```
  (Mảng tuple không Codable: dùng struct nhỏ thay thế, tên do implementer chọn.)

  Test:
  - Dữ liệu giả 90 ngày, tempo bài A tăng từ 60 lên 84 → `exerciseDeltas` của A là (60, 84).
  - Điểm yếu "&" trễ có ở tháng 1 nhưng không còn ở tháng 3 → nằm trong `fixedWeaknesses`.
  - Khoảng thời gian không có dữ liệu → các giá trị `nil`/0, không crash.

  **Màn hình "Hành trình"** (không cần AI):
  - chọn khoảng thời gian: 1 / 3 / 6 tháng / từ đầu;
  - thẻ "Trước → Sau" cho từng bài: tempo sạch, độ lệch, %;
  - dòng thời gian các level đã đạt; tổng giờ tập; chuỗi ngày dài nhất;
  - điểm yếu đã sửa được và điểm yếu còn lại.

  Nút **"Nhờ thầy tổng kết giai đoạn"** gửi `PeriodReview` qua cầu nối Notion (Task 13B), cùng luồng với báo cáo tuần nhưng trang có tên `Tổng kết YYYY-MM-DD`. Thầy viết nhận xét cả giai đoạn và mục tiêu cho 3 tháng tới. App nhắc vào mỗi mốc 3 tháng kể từ buổi tập đầu tiên.
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: long-term practice history, digest, period review and backup`.

### Task 13B: Cầu nối Claude Pro qua Notion (cách mặc định, không tốn API)

Người dùng dùng **gói Claude Pro**. Gói này không có API, nên app không gọi Claude trực tiếp mà đi qua Notion. Claude trong app Claude (Pro) có connector Notion nên đọc/ghi được, còn DrumCoach đọc/ghi qua Notion API bằng internal integration token.

Luồng hoạt động:
1. **Bấm "Gửi cho thầy"** trong DrumCoach. App làm ba việc:
   - tạo trang con `Báo cáo YYYY-MM-DD` dưới trang `DrumCoach › Hộp thư`, chứa `HistoryDigest` và `StudentProfile` dạng JSON trong code block;
   - copy lời nhắn ngắn vào clipboard ("Thầy ơi, xem báo cáo YYYY-MM-DD");
   - mở app Claude bằng `https://claude.ai/new` (universal link).
2. **Trong Project "Thầy dạy trống" trên Claude:** người dùng dán lời nhắn rồi gửi. Theo hướng dẫn của Project, Claude:
   - đọc báo cáo mới nhất trong Hộp thư;
   - phân tích và dùng web search tìm video;
   - tạo trang `Kế hoạch YYYY-MM-DD` dưới `DrumCoach › Kế hoạch`, gồm phần đọc cho người (tiến bộ, 3 điều cần sửa, video) và một code block ```json chứa `TeacherReport`.
3. **Bấm "Đồng bộ"** trong DrumCoach. App tự đồng bộ thêm mỗi lần mở app. App:
   - đọc trang Kế hoạch mới nhất chưa import và ghép các rich_text của code block thành JSON;
   - decode thành `TeacherReport` rồi kiểm tra: DSL parse được, exerciseId có thật, link YouTube có thật (oEmbed);
   - hiện màn hình **"Áp dụng kế hoạch mới?"** để so plan cũ và plan mới;
   - khi bấm Áp dụng thì cập nhật "Hôm nay tập gì", tempo mục tiêu và bài mới vào thư viện, rồi ghi `fixFirst` vào `pastAdvice`.

**Files:** Create `DrumAI/NotionClient.swift`, `DrumAI/NotionBridge.swift`, `DrumAI/TeacherProjectKit.swift`, `App/.../Teacher/SyncView.swift`, `App/.../Teacher/ApplyPlanView.swift`; Test `NotionBridgeTests.swift`

**Interfaces – Produces:**
```swift
public struct NotionClient: Sendable {   // Notion REST API, header "Notion-Version" lấy theo bản hiện hành lúc implement
  public init(token: String, transport: HTTPTransport)
  public func createChildPage(parent: String, title: String, codeBlockJSON: String) async throws -> String   // tách JSON thành các rich_text ≤ 2000 ký tự
  public func childPages(of parent: String) async throws -> [(id: String, title: String, created: Date)]
  public func codeBlocks(of page: String, language: String) async throws -> [String]                       // ghép rich_text lại
}
public struct NotionBridge: Sendable {
  public init(client: NotionClient, inboxPageId: String, plansPageId: String)
  public func send(digest: HistoryDigest, profile: StudentProfile, date: Date) async throws -> (pageTitle: String, prompt: String)
  public func fetchNewPlans(after lastImported: Date?) async throws -> [(title: String, report: Result<TeacherReport, BridgeError>)]
}
public enum BridgeError: Error, Equatable { case noJSONBlock, invalidJSON(String), schemaMismatch(String) }
public enum TeacherProjectKit {
  public static let projectInstructions: String   // hướng dẫn dán vào Project trên claude.ai: vai trò thầy, quy trình đọc Hộp thư → ghi Kế hoạch, schema JSON, ngữ pháp DSL, danh sách exerciseId
}
```
- [ ] **Bước 1: Test** (fake transport):
  - Digest 24 KB → request tạo trang có code block được tách thành các rich_text, mỗi cái ≤ 2000 ký tự; ghép lại phải ra đúng chuỗi ban đầu.
  - Trang Kế hoạch có JSON hợp lệ → `.success`; không có code block → `.noJSONBlock`; JSON hỏng → `.invalidJSON`; thiếu field → `.schemaMismatch`.
  - `fetchNewPlans(after:)` bỏ qua trang cũ hơn hoặc bằng `lastImported`.
  - `projectInstructions` chứa schema `TeacherReport` và ví dụ DSL. Ví dụ JSON trong instructions phải decode được thành `TeacherReport` (test bắt lỗi khi schema code và instructions lệch nhau).
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement.
  - **Màn hình cài đặt một lần** "Kết nối thầy AI", hướng dẫn từng bước kèm nút copy:
    1. Tạo Notion integration và dán token (lưu Keychain).
    2. Tạo trang DrumCoach, share trang đó cho integration, dán link trang. App tự tạo 2 trang con Hộp thư và Kế hoạch.
    3. Trên claude.ai tạo Project "Thầy dạy trống", dán `projectInstructions`, bật connector Notion và web search.
  - Chạy được cả khi không có mạng: báo cáo chờ gửi lại sau.
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: Claude Pro bridge via Notion (send digest, sync and apply plan)`.

**Liên quan đến Task 9, 10, 14:** `ClaudeClient` (API) trở thành **tùy chọn**, chỉ dùng khi người dùng nhập API key trong Settings; khi đó "Gửi cho thầy" chạy tự động hoàn toàn. Không có key thì: đọc PDF làm qua Project (gửi ảnh trang, Claude ghi bài DSL vào trang `DrumCoach › Bài tập mới`, app Sync về), đánh giá Task 10 dùng `localFallback`, còn chat với thầy làm ngay trong Project trên claude.ai (Task 15 bỏ TeacherChatView khi không có key).

### Task 14: Giáo viên AI – báo cáo tuần, kế hoạch, tài liệu gợi ý

**Files:** Create `DrumAI/TeacherReport.swift`, `DrumAI/StudentProfile.swift`, `DrumAI/ResourceValidator.swift`, `App/.../Teacher/TeacherView.swift`, `App/Models/StoredReport.swift`; Test `TeacherReportTests.swift`, `ResourceValidatorTests.swift`

**Interfaces – Produces:**
```swift
public struct StudentProfile: Codable, Sendable, Equatable {
  public var goal: String = "Rockschool Grade 8"; public var instruments: [String] = ["pad", "trống điện"]; public var minutesPerDay: Int = 30
  public var notes: [String]               // người dùng tự ghi: "cổ tay trái yếu", "tập buổi tối"
  public var pastAdvice: [AdviceItem]      // AdviceItem(date, text, followed: Bool?) — thầy nhớ đã dặn gì
}
public struct Resource: Codable, Sendable, Equatable { public let kind: String /* youtube | article | book */ ; public let title: String; public let url: URL?; public let why: String; public let searchQuery: String }
public struct PlannedItem: Codable, Sendable, Equatable { public let exerciseId: String?; public let newExerciseDSL: String?; public let bpm: Int; public let minutes: Int; public let focus: String }
public struct DayPlan: Codable, Sendable, Equatable { public let day: Int /* 1...7 */; public let warmup: [PlannedItem]; public let main: [PlannedItem]; public let fun: [PlannedItem] }
public struct TeacherReport: Codable, Sendable, Equatable {
  public let summary: String; public let progress: [String]; public let fixFirst: [String] /* tối đa 3 điều cần sửa, xếp theo ưu tiên */
  public let likelyCauses: [String]; public let weekPlan: [DayPlan]; public let resources: [Resource]; public let nextCheckpoint: String
}
public enum Teacher {
  public static func weeklyReport(digest: HistoryDigest, profile: StudentProfile, library: [String: String] /* id → tên + skill */, client: ClaudeClient) async throws(ClaudeError) -> TeacherReport
}
public struct ResourceValidator: Sendable {
  public init(transport: HTTPTransport)
  /// YouTube: gọi https://www.youtube.com/oembed?url=<url>&format=json; 200 = video có thật, khác 200 thì thay url bằng link tìm kiếm youtube.com/results?search_query=<searchQuery>.
  /// Link khác: HEAD request, 2xx/3xx thì giữ, không thì thay bằng link tìm kiếm Google.
  public func validate(_ r: [Resource]) async -> [Resource]
}
```
- [ ] **Bước 1: Test** (fake transport):
  - Report JSON hợp lệ → decode đúng.
  - `newExerciseDSL` mà parse lỗi thì bị loại khỏi plan; `exerciseId` không có trong thư viện cũng bị loại.
  - oEmbed 404 → url thành link tìm kiếm chứa `searchQuery` đã encode; oEmbed 200 → giữ nguyên.
  - Request gửi Claude có digest, profile, danh sách id thư viện, và tool `web_search` được bật.
  - Mất mạng → báo lỗi, report cũ vẫn còn.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement.
  - **Gọi Claude:** dùng `claude-opus-5-5` với effort `high`, bật `web_search_20260209` (`max_uses: 5`) để tìm video và tài liệu có thật. Gọi bằng streaming vì báo cáo dài.
  - **System prompt:** Claude đóng vai giáo viên trống kèm 1-1, nói tiếng Việt, cụ thể và nhẹ nhàng. Phải dựa trên số liệu, phải nhắc lại lời khuyên cũ và đánh giá người dùng đã làm theo chưa. Không quá 3 điều cần sửa mỗi tuần. Ưu tiên bài trong thư viện; thiếu thì viết bài mới bằng DSL. Tài liệu ưu tiên kênh uy tín và phải có `searchQuery`.
  - **Màn hình "Thầy AI":**
    - Báo cáo mới nhất: tóm tắt, tiến bộ, 3 điều cần sửa, kế hoạch 7 ngày, danh sách video/tài liệu. Video YouTube mở trong sheet bằng `SFSafariViewController`.
    - Lịch sử các báo cáo trước.
    - Nút "Nhờ thầy xem lại" (tạo báo cáo ngay, không đợi tới Chủ nhật).
    - Sửa hồ sơ học viên.
    - Nhắc vào Chủ nhật: "Đã đến buổi gặp thầy hằng tuần".
  - Mỗi lời khuyên `fixFirst` được thêm vào `pastAdvice`. Báo cáo tuần sau đánh giá `followed` dựa trên lịch sử tập.
  - Hiện ước tính chi phí token trước khi gửi.
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: AI teacher weekly report with plan and validated resources`.

### Task 15: "Hôm nay tập gì" + hỏi thầy + thư viện 40 rudiment

**Files:** Create `DrumLibrary/PASRudiments.swift`, `DrumLibrary/SessionRunner.swift`, `DrumAI/TeacherChat.swift`, `App/.../Today/TodayView.swift`, `App/.../Teacher/TeacherChatView.swift`; Test `SessionRunnerTests.swift`, `PASRudimentsTests.swift`, `TeacherChatTests.swift`

**Interfaces – Produces:**
```swift
public enum PASRudiments { public static let all: [Exercise] }   // 40 rudiment chuẩn PAS do app tự viết bằng DSL (tên và sticking là kiến thức chung)
public struct SessionRunner: Sendable {
  public init(plan: DayPlan)
  public var current: PlannedItem? { get }; public var remaining: TimeInterval { get }
  public mutating func tick(_ dt: TimeInterval) -> Bool          // true = chuyển sang phần tiếp theo
  public mutating func skip(); public var completedMinutes: Double { get }
}
public struct TeacherChat: Sendable {
  public init(client: ClaudeClient, digest: HistoryDigest, profile: StudentProfile, lastReport: TeacherReport?)
  public mutating func ask(_ question: String) async throws(ClaudeError) -> String   // giữ hội thoại; có thể dùng web search
}
```
- [ ] **Bước 1: Test:**
  - `PASRudiments.all.count == 40`, mọi bài parse được và có sticking.
  - SessionRunner: plan 5 + 10 + 10 phút → `tick` qua đúng các mốc 300 s và 900 s; `skip` nhảy sang phần sau; `completedMinutes` đúng.
  - TeacherChat: request thứ hai chứa cả câu hỏi và câu trả lời của lượt trước; lịch sử chat bị cắt khi quá 20 lượt.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement.
  - **TodayView là màn hình chính của app:** lấy DayPlan của hôm nay từ báo cáo mới nhất (chưa có báo cáo thì dùng plan mặc định theo level), bấm "Bắt đầu buổi tập" để chạy lần lượt Khởi động → Bài chính → Bài vui, mỗi phần mở PracticeView với tempo đã đặt sẵn.
  - Hết buổi hiện tổng kết và ô nhật ký.
  - **TeacherChatView:** hỏi đáp tự do ("tại sao tôi hay trễ ở &?"). Thầy thấy được lịch sử và báo cáo gần nhất.
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: today's structured session, teacher chat and PAS rudiments`.

### Task 16: Sách Rockschool → Grade test, Ear Test, GMQ, Bài học nền tảng, MIDI learn

**Files:** Create `DrumLibrary/GradeSyllabus.swift`, `DrumLibrary/PrivateLibraryLoader.swift`, `DrumLibrary/EarTest.swift`, `DrumLibrary/GMQuiz.swift`, `DrumAudio/DrumSynth.swift`, `DrumAudio/MIDILearn.swift`, `App/.../Lessons/LessonsView.swift`, `PrivateLibrary/README.md` (chỉ README được commit); Test `GradeSyllabusTests.swift`, `EarTestTests.swift`, `GMQuizTests.swift`, `MIDILearnTests.swift`

**Interfaces – Produces:**
```swift
public struct GradeSyllabus: Codable, Sendable { public let grade: Int; public let techGroups: [LevelTestItem]; public let fills: [LevelTestItem]; public let sightReadingBpm: Int; public let source: String /* "book" | "generated" */ }
public enum PrivateLibraryLoader { public static func load(from dir: URL) throws -> [GradeSyllabus]  // đọc PrivateLibrary/grade-N.json; thiếu file thì fallback LevelCatalog
                                    public static func missingGrades(available: [Int], current: Int) -> [Int] }
public enum EarTestKind: String, Codable, Sendable { case fillPlayback, grooveRecall }
public struct EarTest: Sendable { public init(kind: EarTestKind, grade: Int, seed: UInt64)
  public let prompt: Exercise; public let choices: [Exercise] /* fillPlayback: 2 lựa chọn */ ; public let bpm: Double
  public func score(played: SessionStats, chosenIndex: Int?) -> Double }
public struct GMQuestion: Codable, Sendable { public let text: String; public let options: [String]; public let answer: Int; public let grade: Int }
public enum GMQuiz { public static func questions(grade: Int, seed: UInt64) -> [GMQuestion] }   // G1: bộ phận trống trên khuông, số chỉ nhịp, nốt đen và móc đơn, dấu lặng, tên các bộ phận
public struct MIDILearn: Sendable { public init(); public mutating func expect(_ v: Voice); public mutating func received(note: UInt8) -> Voice?; public var map: [UInt8: Voice] { get } }
```
- [ ] **Bước 1: Test:**
  - Thư mục PrivateLibrary rỗng → loader trả về rỗng và app dùng `LevelCatalog`; `grade-1.json` hợp lệ → tech groups ở ♩=70.
  - `missingGrades(available: [1,2,3,4], current: 4) == [5]`; `missingGrades(available: [1,2,3,4,5], current: 5) == [6,7,8]`.
  - `EarTest(.grooveRecall)` sinh groove 2 ô nhịp với HH/SN/BD, cùng seed thì ra cùng kết quả.
  - `fillPlayback` đánh đúng nhịp và chọn đúng đáp án → điểm 100; chọn sai → trừ điểm nhận biết.
  - Mọi câu GMQ có `answer` nằm trong khoảng của `options`.
  - MIDILearn: expect(.snare) rồi received(38) → map[38] == .snare; sau đó received(38) thì trả về .snare.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement.
  - **Chuyển sách sang dữ liệu:** dùng Claude (qua Project/Notion, Task 13B, hoặc API) đọc trang Technical Exercises của từng grade rồi ghi ra `PrivateLibrary/grade-N.json`. Người dùng xem trước trên khuông nhạc rồi xác nhận.
  - **Ear Test:** `DrumSynth` phát mẫu bằng âm trống tổng hợp, có count-in 1 ô nhịp; người dùng đánh lại; chấm bằng HitMatcher.
  - **GMQ:** dạng quiz trắc nghiệm.
  - **LessonsView:** 8 bài từ `docs/giao-trinh.html`, mỗi bài có checklist tự kiểm tra và nút "Tập ngay" mở bài tập tương ứng. Ví dụ bài 3 mở bài chỉ-tay-phải / chỉ-tay-trái ở 50 BPM.
  - **MIDI learn cho TD-7:** nằm trong Settings, hướng dẫn đánh lần lượt từng pad.
  - **Thông báo khi đạt grade mà thiếu sách grade sau:** dùng `missingGrades`.
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: Rockschool grade syllabus, ear tests, GMQ quiz, lessons and MIDI learn`.

---

## Mốc 9 (tùy chọn): Play-along

### Task 12: Chơi theo backing track

**Files:** Create `DrumAudio/BackingTrackPlayer.swift`, `App/.../Practice/PlayAlongView.swift`; Test `BackingTrackTests.swift`

- [ ] **Bước 1: Test:** tính `rate = targetBpm / originalBpm`; điểm loop A–B tính bằng giây, đổi sang sample frame chính xác; điểm A ≥ B thì báo lỗi.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement. Người dùng nhập file audio (ví dụ backing track của sách Rockschool mà họ sở hữu), `AVAudioUnitTimePitch` đổi tốc độ mà không đổi cao độ, đặt beat 1 bằng cách tap, metronome đồng bộ theo, loop A–B. Có tùy chọn ghi âm lần chơi để nghe lại.
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: play-along with tempo change and A-B loop`.

---

## Thứ tự và kiểm tra cuối

Thứ tự làm: Task 1 → 2 → 3 → 4 → 5 → 6 → 7 → 7A. Đến đây đã có app dùng được hằng ngày: metronome, giọng đếm mượt, khuông nhạc chạy, đo sớm/trễ, luyện đếm. Sau đó làm 8 → 9 → 10 → 10A → 13 → 13B → 14 → 15 → 16 → 11 → 12. Ở Task 14, phần `TeacherReport`, `StudentProfile` và `ResourceValidator` dùng chung cho cả hai đường (Notion và API). Chỉ hàm `Teacher.weeklyReport` là thuộc đường API. Giáo viên AI (13–15) được làm trước biểu đồ tiến độ (11), vì người dùng không có giáo viên thật.

**Stick Control trong app:** generator ở Task 8 sinh các tổ hợp sticking cùng kiểu. Bài trong sách thật thì người dùng nhập qua PDF (Task 9). Mỗi bài mặc định lặp 20 lần liên tục rồi mới chuyển bài, tempo ramp 50 → 90.

Sau mỗi mốc chạy:
```bash
cd Packages/DrumKit && swift test                       # tất cả PASS
xcodegen generate && xcodebuild -scheme DrumCoach -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build   # BUILD SUCCEEDED
```
Kiểm tra trên iPad thật là bắt buộc với Task 3, 6 và 7 (độ trễ âm thanh và micro trên simulator không giống máy thật).
