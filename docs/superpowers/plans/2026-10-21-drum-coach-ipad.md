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

**Các quyết định Claude tự đưa ra (người dùng có thể đổi):**
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
- Model Claude mặc định là `claude-sonnet-5-5`, có thể chọn `claude-opus-5-5` trong Settings. Endpoint `https://api.anthropic.com/v1/messages`, header `anthropic-version: 2023-06-01`.
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
public struct ClickEvent: Sendable, Hashable { public let sampleTime: Int64; public let kind: ClickKind; public let bar: Int }
public struct MetronomeSettings: Sendable, Codable, Equatable {
  public var bpm: Double; public var timeSignature: TimeSignature
  public var clickSubdivision: CountMode        // phát click ở mức chia nào
  public var voiceCount: CountMode?             // nil = tắt giọng đếm
  public var accentDownbeat: Bool
  public var backbeatOnly: Bool                 // click chỉ vào phách 2 và 4
  public var gap: GapPattern?                   // GapPattern(playBars: 2, muteBars: 2)
  public var volume: Float; public var voiceVolume: Float
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
@Test func backbeatOnly() { /* chỉ có phách 2 và 4 */ }
@Test func voiceSyllables() { /* voiceCount .sixteenths → kinds .voice("1"), .voice("e"), .voice("&"), .voice("a") */ }
```
- [ ] **Bước 2:** `swift test --filter DrumAudioTests` → FAIL.
- [ ] **Bước 3:** Implement `ClickSchedule` (thuần). `MetronomeEngine` dùng một `AVAudioSourceNode` render callback: mỗi buffer gọi `ClickSchedule.events` cho đoạn sample của buffer đó rồi mix sample click hoặc giọng vào đúng frame offset. Cách này cho độ chính xác tới từng sample và không phụ thuộc vào timer. `CountVoiceBank` dùng `AVSpeechSynthesizer.write(_:toBufferCallback:)` render trước các âm tiết "one…twelve, e, and, a, trip, let" thành `AVAudioPCMBuffer` ở 48 kHz, cắt bỏ khoảng lặng đầu, rồi cache vào thư mục Caches. **Giọng đếm phải liền mạch** (người dùng phàn nàn rằng tiếng đếm bị giật ở âm "&"): mỗi âm tiết có fade-in 3 ms và fade-out 15 ms, không bao giờ bị cắt cụt; nếu âm tiết dài hơn ô thời gian của nó ở tempo hiện tại thì nén thời lượng (time-compress, giữ cao độ) cho vừa 90% ô; phách chính đọc to hơn "e & a" 4 dB để nghe ra nhịp điệu nói tự nhiên. Có thêm tùy chọn **tự ghi âm giọng mình** cho từng âm tiết trong Settings. Thêm test thuần `syllableFitsSlot`: hàm `CountVoiceBank.stretchFactor(syllableDuration: 0.35, slot: 60/90/4)` phải trả về < 1 và kết quả × 0.35 ≤ 0.9 × slot. Đặt `AVAudioSession` là `.playAndRecord` với `[.defaultToSpeaker, .allowBluetoothA2DP]` và `setPreferredIOBufferDuration(0.005)`.
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
  /// Gọi Messages API, ép trả về JSON qua một tool duy nhất (tool_choice: {type: "tool", name}), trả về `input` của tool đã decode.
  public func structured<T: Decodable & Sendable>(system: String, content: [ContentBlock], toolName: String, schema: JSONValue, as: T.Type, maxTokens: Int) async throws(ClaudeError) -> T
}
public enum ContentBlock: Sendable { case text(String), imagePNG(Data) }
public enum ClaudeError: Error, Equatable { case missingKey, http(Int, String), noToolUse, decoding(String), network(String) }
public enum PageTranscriber { public static func transcribe(pagePNG: Data, client: ClaudeClient) async throws(ClaudeError) -> [String /* DSL */] }
```
- [ ] **Bước 1: Test** (fake transport):
  - request có header `x-api-key`, `anthropic-version: 2023-06-01`, body có `model`, `tools[0].name`, `tool_choice`;
  - response mẫu có block `tool_use` thì decode thành T;
  - status 401 → `.http(401, …)`; response không có `tool_use` → `.noToolUse`;
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

## Mốc 8 (tùy chọn): Play-along

### Task 12: Chơi theo backing track

**Files:** Create `DrumAudio/BackingTrackPlayer.swift`, `App/.../Practice/PlayAlongView.swift`; Test `BackingTrackTests.swift`

- [ ] **Bước 1: Test:** tính `rate = targetBpm / originalBpm`; điểm loop A–B tính bằng giây, đổi sang sample frame chính xác; điểm A ≥ B thì báo lỗi.
- [ ] **Bước 2:** FAIL. **Bước 3:** Implement. Người dùng nhập file audio (ví dụ backing track của sách Rockschool mà họ sở hữu), `AVAudioUnitTimePitch` đổi tốc độ mà không đổi cao độ, đặt beat 1 bằng cách tap, metronome đồng bộ theo, loop A–B. Có tùy chọn ghi âm lần chơi để nghe lại.
- [ ] **Bước 4:** PASS. **Bước 5:** Commit `feat: play-along with tempo change and A-B loop`.

---

## Thứ tự và kiểm tra cuối

Thứ tự làm: Task 1 → 2 → 3 → 4 → 5 → 6 → 7 → 7A. Đến đây đã có app dùng được hằng ngày: metronome, giọng đếm mượt, khuông nhạc chạy, đo sớm/trễ, luyện đếm. Sau đó làm 8 → 9 → 10 → 10A → 11 → 12.

**Stick Control trong app:** generator ở Task 8 sinh các tổ hợp sticking cùng kiểu. Bài trong sách thật thì người dùng nhập qua PDF (Task 9). Mỗi bài mặc định lặp 20 lần liên tục rồi mới chuyển bài, tempo ramp 50 → 90.

Sau mỗi mốc chạy:
```bash
cd Packages/DrumKit && swift test                       # tất cả PASS
xcodegen generate && xcodebuild -scheme DrumCoach -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build   # BUILD SUCCEEDED
```
Kiểm tra trên iPad thật là bắt buộc với Task 3, 6 và 7 (độ trễ âm thanh và micro trên simulator không giống máy thật).
