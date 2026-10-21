import DrumAnalysis
import DrumAudio
import DrumCore
import DrumLibrary
import SwiftData
import SwiftUI
import UIKit

/// The practice screen: one stage with the notation and the hand lanes, one row of controls under it.
struct PracticeView: View {
    @StateObject private var model: PracticeViewModel
    @State private var showSound = false
    @State private var showCalibration = false
    @State private var showCamera = false
    @State private var taps: [Date] = []
    @Environment(\.modelContext) private var modelContext
    private let voiceBank: CountVoiceBank
    private let exercises: [Exercise]

    init(exercises: [Exercise], voiceBank: CountVoiceBank, testItem: LevelTestItem? = nil, bpm: Double? = nil) {
        self.exercises = exercises
        self.voiceBank = voiceBank
        let vm = PracticeViewModel(exercise: exercises[0], voiceBank: voiceBank, testItem: testItem)
        if let bpm, testItem == nil { vm.settings.bpm = bpm }
        _model = StateObject(wrappedValue: vm)
    }

    var body: some View {
        TimelineView(.animation(paused: !model.isPlaying)) { _ in
            let beat = model.beat(atHostTime: HostClock.now())
            let pass = model.currentRepeat(beat: beat)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let note = statusNote { Label(note.text, systemImage: note.icon).font(.callout).foregroundStyle(note.color) }
                    Stage {
                        VStack(alignment: .leading, spacing: 14) {
                            NotationView(exercise: model.playedExercise, display: model.display, beat: beat,
                                         noteColor: { model.color(noteIndex: $0, repeat: pass) },
                                         orangeOffsetMs: { model.orangeOffsetMs(noteIndex: $0, repeat: pass) })
                            Divider().overlay(Theme.hairline)
                            RLStripView(timeline: model.displayTimeline, exercise: model.playedExercise,
                                        countMode: model.settings.voiceCount ?? .eighths, beat: beat,
                                        noteColor: { tn in model.results[tn.index].map { model.rules.grade($0).color } })
                        }
                    }
                    controls(beat: beat)
                    if model.mode == .touch { touchPads }
                    options
                    if let auto = model.autoLearn { autoLearnStatus(auto) }
                }
                .padding(Theme.pagePadding)
            }
            .background(Theme.canvas)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSound) { MetronomeSheet(settings: $model.settings) }
        .sheet(isPresented: $showCalibration) { CalibrationView(voiceBank: voiceBank) }
        .sheet(isPresented: $showCamera) { PostureCameraView(exerciseTitle: model.exercise.title) }
        .sheet(item: $model.finishedStats) { stats in
            ResultsView(stats: stats, title: model.exercise.title, bpm: model.settings.bpm,
                        input: model.assessmentInput(for: stats), session: model.lastSession, diagnosis: model.lastDiagnosis, samples: model.lastSamples)
        }
        .onAppear { model.modelContext = modelContext }
        .onChange(of: model.settings) { _, new in if model.autoLearn == nil, model.testItem == nil { SettingsStore.saveMetronome(new) } }
        .onDisappear { model.stop(); model.stopListening() }
    }

    // MARK: Header

    private var header: some View {
        PageHeader(title: ExerciseTitle.short(model.exercise.title), subtitle: subtitle) {
            HStack(spacing: 6) {
                if exercises.count > 1 {
                    Menu {
                        ForEach(exercises) { ex in Button(ex.title) { model.stop(); model.exercise = ex } }
                    } label: { iconLabel("list.bullet", L("Chọn bài", "Choose exercise")) }
                }
                Button { model.listen() } label: { iconLabel("speaker.wave.2", L("Nghe mẫu", "Listen")) }
                    .disabled(model.isPlaying)
                Button { showCamera = true } label: { iconLabel("camera", L("Soi tư thế", "Check posture")) }
                Button { showCalibration = true } label: { iconLabel("dot.radiowaves.left.and.right", L("Hiệu chỉnh độ trễ", "Latency calibration")) }
                Button { showSound = true } label: { iconLabel("slider.horizontal.3", L("Âm thanh máy nhịp", "Metronome sound")) }
                    .disabled(model.isPlaying)
                Menu {
                    if let url = GrooveScribeExport.url(for: model.exercise, bpm: Int(model.settings.bpm)) {
                        Link(destination: url) { Label(L("Mở trong GrooveScribe", "Open in GrooveScribe"), systemImage: "safari") }
                        ShareLink(item: url) { Label(L("Chia sẻ link GrooveScribe", "Share GrooveScribe link"), systemImage: "link") }
                    }
                    Button { printNotation() } label: { Label(L("In bản nhạc (PDF)", "Print notation (PDF)"), systemImage: "printer") }
                } label: { iconLabel("square.and.arrow.up", L("Xuất bài", "Export exercise")) }
            }
        }
    }

    private var subtitle: String {
        let e = model.exercise
        var parts = ["\(e.timeSignature.beats)/\(e.timeSignature.unit)", L("\(e.bars) ô nhịp", e.bars == 1 ? "1 bar" : "\(e.bars) bars")]
        if let r = model.loopBars { parts.append(L("đang lặp ô \(r.lowerBound)–\(r.upperBound)", "looping bar \(r.lowerBound)–\(r.upperBound)")) }
        if model.testItem != nil { parts.append(L("bài kiểm tra cấp độ", "level test")) }
        return parts.joined(separator: ", ")
    }

    private func iconLabel(_ icon: String, _ title: String) -> some View {
        Image(systemName: icon).font(.body.weight(.medium)).frame(width: 40, height: 40)
            .background(Circle().fill(Theme.stage))
            .accessibilityLabel(title)
    }

    private var statusNote: (text: String, icon: String, color: Color)? {
        if let e = model.error { return (e, "exclamationmark.circle", Theme.missed) }
        if let r = model.scoringOffReason, model.isPlaying { return (r, "speaker.wave.2", Theme.offTime) }
        if model.showHeadphoneWarning {
            return (L("Âm thanh đang ra loa. Cắm tai nghe để app chấm điểm khi tập với pad.", "Sound is coming from the speaker. Plug in headphones so the app can score you on a pad."), "headphones", .secondary)
        }
        if model.testItem != nil { return (L("Tempo, thời lượng và độ khó cố định. Cần trên 90% để đạt.", "Tempo, length and difficulty are fixed. You need above 90% to pass."), "lock", .secondary) }
        return nil
    }

    // MARK: Controls

    private func controls(beat: Double?) -> some View {
        HStack(alignment: .center, spacing: 28) {
            TempoControl(bpm: $model.settings.bpm, disabled: model.isPlaying || model.testItem != nil || model.autoLearn != nil)
            Button(L("Gõ", "Tap")) { tapTempo() }
                .font(.callout.weight(.medium))
                .disabled(model.isPlaying || model.testItem != nil)
            Spacer()
            PlayButton(isPlaying: model.isPlaying, beatPhase: (beat ?? 0) - floor(beat ?? 0)) {
                model.isPlaying ? model.stop() : model.play()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Readout(value: model.liveScore.map { "\(Int($0.rounded()))%" } ?? "–", caption: L("Điểm", "Score"), size: 44,
                        tint: model.liveScore.map { $0 > 90 ? Theme.onTime : $0 >= 60 ? Theme.offTime : Theme.missed } ?? .primary)
                TimingStrip(recent: model.recent).frame(width: 220)
            }
        }
    }

    private var options: some View {
        HStack(spacing: 10) {
            optionMenu(L("Thời lượng", "Length"), value: label(forSeconds: model.durationSeconds)) {
                ForEach([30.0, 60, 120, 300], id: \.self) { s in Button(label(forSeconds: s)) { model.durationSeconds = s } }
            }
            .disabled(model.testItem != nil || model.autoLearn != nil)
            optionMenu(L("Nhận tiếng", "Input"), value: model.mode.title) {
                ForEach(InputMode.allCases) { m in Button(m.title) { model.mode = m } }
            }
            optionMenu(L("Độ khó", "Difficulty"), value: difficultyText) {
                Button(L("Dễ, ±45 ms", "Easy, ±45 ms")) { setDifficulty(45) }
                Button(L("Vừa, ±30 ms", "Medium, ±30 ms")) { setDifficulty(30) }
                Button(L("Khó, ±20 ms", "Hard, ±20 ms")) { setDifficulty(20) }
            }
            .disabled(model.testItem != nil)
            optionMenu(L("Lặp", "Loop"), value: model.loopBars.map { L("Ô \($0.lowerBound)–\($0.upperBound)", "Bar \($0.lowerBound)–\($0.upperBound)") } ?? L("Cả bài", "Whole exercise")) {
                Button(L("Cả bài", "Whole exercise")) { model.loopBars = nil }
                ForEach(1...max(1, model.exercise.bars), id: \.self) { b in Button(L("Ô \(b)", "Bar \(b)")) { model.loopBars = b...b } }
                if model.exercise.bars >= 2 {
                    ForEach(Array(stride(from: 1, to: model.exercise.bars, by: 2)), id: \.self) { b in
                        Button(L("Ô \(b)–\(min(b + 1, model.exercise.bars))", "Bar \(b)–\(min(b + 1, model.exercise.bars))")) { model.loopBars = b...min(b + 1, model.exercise.bars) }
                    }
                }
            }
            .disabled(model.testItem != nil || model.autoLearn != nil)
            Toggle(isOn: $model.flipped) { Text(L("Đổi tay", "Switch hands")) }
                .toggleStyle(.button)
                .disabled(model.testItem != nil)
            Spacer()
            if model.testItem == nil {
                Button(model.autoLearn == nil ? L("Học tự động", "Auto-learn") : L("Thoát học tự động", "Exit auto-learn")) {
                    model.autoLearn == nil ? model.startAutoLearn() : model.stopAutoLearn()
                }
                .buttonStyle(.bordered)
            }
            Picker(L("Hiển thị", "Display"), selection: $model.display) {
                ForEach(NotationDisplay.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 150)
        }
        .disabled(model.isPlaying)
        .font(.callout)
    }

    private func optionMenu<Content: View>(_ title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        Menu(content: content) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).foregroundStyle(.primary)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.stage))
        }
    }

    private func autoLearnStatus(_ a: PracticeViewModel.AutoLearnState) -> some View {
        Stage {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L("Học tự động", "Auto-learn")).font(.headline)
                    Spacer()
                    if let step = a.step {
                        Text(L("Bước \(a.stepIndex + 1)/\(a.plan.steps.count): \(step.title)", "Step \(a.stepIndex + 1)/\(a.plan.steps.count): \(step.title)")).foregroundStyle(.secondary)
                    }
                }
                if a.finished {
                    Label(L("Xong! Bạn đã chơi cả bài không cần click ở tempo mục tiêu.", "Done! You played the whole exercise without a click at the target tempo."), systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.onTime)
                } else {
                    ProgressView(value: Double(a.stepIndex), total: Double(a.plan.steps.count)).tint(Theme.shell)
                    Text(L("Tempo \(a.tempo.bpm)/\(a.tempo.target) BPM. Trên 90% thì tăng 5 BPM; trượt 3 lần liền thì giảm 10. Đạt tempo mục tiêu trên 90% thì sang bước sau.", "Tempo \(a.tempo.bpm)/\(a.tempo.target) BPM. Above 90% raises it by 5 BPM; 3 misses in a row lowers it by 10. Reach the target tempo above 90% to move to the next step."))
                        .font(.callout).foregroundStyle(.secondary)
                    if let s = a.lastScore { Text(L("Lần vừa rồi: \(Int(s.rounded()))%", "Last run: \(Int(s.rounded()))%")).font(.callout) }
                }
            }
        }
    }

    /// Two big pads for "Gõ màn hình": right hand, left hand (any drum counts).
    private var touchPads: some View {
        HStack(spacing: 16) {
            ForEach(["L", "R"], id: \.self) { hand in
                Text(hand)
                    .font(Theme.number(40))
                    .foregroundStyle(hand == "R" ? Theme.shell : .secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.stage))
                    .contentShape(Rectangle())
                    // Fire on touch-down, not release, so timing is honest.
                    .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { v in
                        if v.translation == .zero { model.tap(nil) }
                    })
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(hand == "R" ? L("Tay phải", "Right hand") : L("Tay trái", "Left hand"))
            }
        }
        .disabled(!model.isPlaying)
        .opacity(model.isPlaying ? 1 : 0.5)
    }

    @MainActor
    private func printNotation() {
        let renderer = ImageRenderer(content:
            NotationView(exercise: model.playedExercise, display: .page, beat: nil, noteColor: { _ in nil }, orangeOffsetMs: { _ in nil }, allPages: true)
                .padding(36).frame(width: 842).background(Color.white).environment(\.colorScheme, .light))
        // Titles can contain "/" and other characters that are not valid in a file name.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DrumCoach-\(UUID().uuidString).pdf")
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: CGSize(width: max(size.width, 842), height: max(size.height, 595)))
            guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil); draw(ctx); ctx.endPDFPage(); ctx.closePDF()
        }
        let printer = UIPrintInteractionController.shared
        printer.printingItem = url
        printer.present(animated: true)
    }

    // MARK: Helpers

    private func label(forSeconds s: Double) -> String { s < 60 ? L("\(Int(s)) giây", "\(Int(s)) sec") : L("\(Int(s / 60)) phút", "\(Int(s / 60)) min") }

    private var difficultyText: String {
        switch Int((model.rules.goodWindow * 1000).rounded()) {
        case 45: L("Dễ", "Easy")
        case 20: L("Khó", "Hard")
        default: L("Vừa", "Medium")
        }
    }

    private func setDifficulty(_ ms: Double) {
        SettingsStore.scoring = ScoringRules(goodWindow: ms / 1000)
        model.rules = SettingsStore.scoring
    }

    private func tapTempo() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 3 } + [now]
        guard taps.count >= 3 else { return }
        let intervals = zip(taps, taps.dropFirst()).map { $1.timeIntervalSince($0) }
        model.settings.bpm = min(300, max(30, (60 / (intervals.reduce(0, +) / Double(intervals.count))).rounded()))
    }
}
