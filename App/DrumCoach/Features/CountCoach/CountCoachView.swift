import DrumAnalysis
import DrumAudio
import DrumCore
import SwiftUI

/// Practise counting out loud evenly: listen → count along → the voice fades → count alone with a gapped click.
struct CountCoachView: View {
    enum Phase: Int, CaseIterable, Identifiable {
        case listen = 1, along, fade, alone
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .listen: L("1. Nghe", "1. Listen")
            case .along: L("2. Đếm cùng", "2. Count along")
            case .fade: L("3. Giọng nhỏ dần", "3. Fading voice")
            case .alone: L("4. Tự đếm", "4. Count alone")
            }
        }
        var hint: String {
            switch self {
            case .listen: L("Chỉ nghe app đếm. Để ý \"&\" nằm đúng giữa hai số.", "Just listen to the app count. Notice the \"&\" sits exactly halfway between two numbers.")
            case .along: L("Đeo tai nghe, nói to và liền hơi cùng app, như một câu hát.", "Put on headphones and count out loud with the app, in one breath, like a line of a song.")
            case .fade: L("Giọng app nhỏ dần rồi tắt sau 4 ô nhịp. Bạn giữ nguyên nhịp đếm.", "The app's voice fades and cuts out after 4 bars. Keep counting at the same pace.")
            case .alone: L("Chỉ còn click, và click tắt 2 ô nhịp xen kẽ. Bạn tự đếm đều.", "Only the click is left, and it drops out every other 2 bars. Count steadily on your own.")
            }
        }
    }

    /// How the player gives the count: out loud, fingers on a table (heard by the mic), or the screen (silent).
    enum Answer: String, CaseIterable, Identifiable {
        case voice, table, screen
        var id: String { rawValue }
        var title: String {
            switch self {
            case .voice: L("Nói", "Speak")
            case .table: L("Gõ bàn", "Tap table")
            case .screen: L("Chạm màn hình", "Tap screen")
            }
        }
        var hint: String {
            switch self {
            case .voice: L("Đếm to thành tiếng.", "Count out loud.")
            case .table: L("Đếm thầm, gõ ngón tay xuống bàn đúng mỗi âm (vd. \"1 &\" là 8 cú mỗi ô nhịp). Đặt iPad trên cùng mặt bàn, đeo tai nghe.", "Count silently and tap a finger on the table for every syllable (e.g. \"1 &\" is 8 taps a bar). Put the iPad on the same table and wear headphones.")
            case .screen: L("Đếm thầm, chạm vào ô lớn bên dưới đúng mỗi âm. Tập được cả ở nơi phải giữ im lặng.", "Count silently and tap the big area below for every syllable. Works even where you must stay quiet.")
            }
        }
    }

    let voiceBank: CountVoiceBank
    @AppStorage("countCoach.answer") private var answer: Answer = .voice
    @State private var touch: TouchHitSource?
    @State private var stage: Phase = .listen
    @State private var mode: CountMode = .eighths
    @State private var bpm: Double = 60
    @State private var run: Task<Void, Never>?
    @State private var result: CountEvenness?
    @State private var judge: CountJudge?
    @State private var lastMark: CountJudge.Mark?
    @State private var summary: CountJudge.Summary?
    @State private var heard = 0
    @State private var error: String?
    @State private var engine: MetronomeEngine?

    private let bars = 8
    private var running: Bool { run != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: L("Đếm nhịp", "Counting"), subtitle: L("Đếm to theo click. App nghe giọng bạn và đo độ đều của từng âm.", "Count out loud with the click. The app listens to your voice and measures how even each syllable is."))
                Stage {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker(L("Giai đoạn", "Phase"), selection: $stage) { ForEach(Phase.allCases) { Text($0.title).tag($0) } }
                            .pickerStyle(.segmented)
                            .disabled(running)
                        Text(stage.hint).foregroundStyle(.secondary)
                        Picker(L("Cách đếm", "Counting style"), selection: $mode) {
                            Text("1 2 3 4").tag(CountMode.quarters)
                            Text("1 & 2 &").tag(CountMode.eighths)
                            Text("1 e & a").tag(CountMode.sixteenths)
                            Text("1 trip let").tag(CountMode.triplets)
                        }
                        .pickerStyle(.segmented)
                        .disabled(running)
                        if stage != .listen {
                            Picker(L("Cách đếm theo", "Count by"), selection: $answer) { ForEach(Answer.allCases) { Text($0.title).tag($0) } }
                                .pickerStyle(.segmented)
                                .disabled(running)
                            Text(answer.hint).font(.callout).foregroundStyle(.secondary)
                        }
                        syllables
                        HStack(spacing: 28) {
                            PlayButton(isPlaying: running) { running ? stop() : start() }
                            TempoControl(bpm: $bpm, range: 40...120, disabled: running)
                            Spacer()
                            Readout(value: running ? "\(heard)" : summary.map { "\($0.score)" } ?? "–",
                                    caption: running ? L("âm đã nghe", "syllables heard") : L("điểm", "score"), size: 44)
                        }
                        if running, judge != nil { liveView }
                        if running, let touch { tapPad(touch) }
                    }
                }
                        if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Theme.missed) }
                if let summary { resultView(summary, evenness: result) }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.canvas)
        .onDisappear { stop() }
    }

    /// One bar of syllables; the one being counted lights up while running.
    private var syllables: some View {
        TimelineView(.animation(paused: !running)) { _ in
            let labels = Counting.labels(mode: mode, beats: 4)
            let now = engine?.beatZeroHostTime.map { (HostClock.now() - $0) * bpm / 60 }
            let inBar = now.flatMap { $0 >= 0 ? $0.truncatingRemainder(dividingBy: 4) : nil }
            let current = inBar.flatMap { b in labels.lastIndex { $0.position.doubleValue <= b + 1e-6 } }
            HStack(spacing: 8) {
                ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                    Text(l.label)
                        .font(Theme.number(labels.count > 8 ? 22 : 30))
                        .foregroundStyle(i == current ? Theme.shell : Color.secondary.opacity(0.45))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Big silent tap target for "Tap screen"; registers on touch-down so the timing is the finger's, not the lift's.
    private func tapPad(_ source: TouchHitSource) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Theme.shell.opacity(0.12))
            .overlay(Text(L("Chạm vào đây theo từng âm", "Tap here on every syllable")).font(.headline).foregroundStyle(Theme.shell))
            .frame(height: 180)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in if v.translation == .zero { source.tap(nil) } })
            .accessibilityAddTraits(.isButton)
    }

    /// While counting: the syllable just heard and how it landed, plus running totals (misses appear as they pass).
    private var liveView: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let live = judge?.summary(until: HostClock.now())
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                if let m = lastMark {
                    Text(m.label).font(Theme.number(40))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verdictText(m.verdict)).font(.title3.weight(.semibold)).foregroundStyle(verdictColor(m.verdict))
                        Text(String(format: "%+.0f ms", m.offsetMs)).font(Theme.number(15, weight: .medium)).foregroundStyle(.secondary)
                    }
                } else {
                    Text(L("Bắt đầu đếm từ ô nhịp 2…", "Start counting from bar 2…")).foregroundStyle(.secondary)
                }
                Spacer()
                if let live { counts(live) }
            }
        }
    }

    private func counts(_ s: CountJudge.Summary) -> some View {
        HStack(spacing: 14) {
            countCell(s.onTime, L("Đúng", "On time"), Theme.onTime)
            countCell(s.early, L("Sớm", "Early"), Theme.offTime)
            countCell(s.late, L("Muộn", "Late"), Theme.offTime)
            countCell(s.missed, L("Trượt", "Missed"), Theme.missed)
        }
    }

    private func countCell(_ n: Int, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(Theme.number(22)).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func verdictText(_ v: CountJudge.Verdict) -> String {
        switch v {
        case .onTime: L("Đúng", "On time")
        case .early: L("Sớm", "Early")
        case .late: L("Muộn", "Late")
        }
    }

    private func verdictColor(_ v: CountJudge.Verdict) -> Color { v == .onTime ? Theme.onTime : Theme.offTime }

    private func resultView(_ s: CountJudge.Summary, evenness r: CountEvenness?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Kết quả: \(s.score) điểm", "Result: \(s.score) points")).font(.title3.weight(.semibold))
                Spacer()
                counts(s)
            }
            if let r, !r.offsetsByLabel.isEmpty { labelRow(r) }
            Text(L("Cần cải thiện", "What to work on")).font(.headline)
            ForEach(Array(s.tips.enumerated()), id: \.offset) { i, tip in
                Label(tip, systemImage: s.tips.count == 1 && s.missed == 0 && s.early + s.late == 0 ? "checkmark.circle" : "\(i + 1).circle")
            }
            Label(L("Đã lưu vào báo cáo tuần gửi thầy AI (Thầy AI → Gửi cho thầy).", "Saved for the weekly report to the AI teacher (AI teacher → Send to teacher)."), systemImage: "tray.and.arrow.up")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func labelRow(_ r: CountEvenness) -> some View {
        HStack(spacing: 10) {
            ForEach(r.offsetsByLabel.sorted { $0.key < $1.key }, id: \.key) { label, ms in
                VStack {
                    Text(label == "number" ? L("số", "number") : label).font(Theme.number(24))
                    Text(String(format: "%+.0f ms", ms)).font(Theme.number(13, weight: .medium))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill((abs(ms) <= 25 ? Theme.onTime : Theme.offTime).opacity(0.16)))
            }
        }
    }

    private func start() {
        run = Task { await go(); run = nil; engine = nil }
    }

    private func stop() {
        run?.cancel()
    }

    private func go() async {
        // The run uses the settings it started with, even if the screen changes meanwhile.
        let stage = self.stage, mode = self.mode, bpm = self.bpm
        result = nil; summary = nil; judge = nil; lastMark = nil; heard = 0; error = nil
        var s = MetronomeSettings(bpm: bpm, pattern: .quarter, accentBeatOne: true, voiceCount: mode)
        switch stage {
        case .listen, .along: s.voiceVolume = 1
        case .fade: s.voiceVolume = 0.5
        case .alone: s.voiceCount = nil; s.gap = GapPattern(playBars: 2, muteBars: 2)
        }
        let metro = MetronomeEngine(voiceBank: voiceBank)
        engine = metro
        let barSeconds = 4 * 60 / bpm
        let answer = self.answer
        let latency = SettingsStore.latency(for: answer == .screen ? .touch : .pad)
        let sensitivity = SettingsStore.micSensitivity
        let source: any HitSource = switch answer {
        case .voice: MicOnsetSource(calibrationOffset: latency) { SyllableOnsetDetector(sampleRate: $0) }
        case .table: MicOnsetSource(calibrationOffset: latency) { OnsetDetector.fingerTaps(sampleRate: $0, sensitivity: sensitivity) }
        case .screen: TouchHitSource(calibrationOffset: latency)
        }
        do {
            try AudioSessionConfig.activate()
            if stage != .listen { try source.start() }
            try metro.start(settings: s)
        } catch {
            self.error = L("Không mở được âm thanh: \(error.localizedDescription)", "Couldn't open audio: \(error.localizedDescription)")
            source.stop()
            return
        }
        if stage != .listen { touch = source as? TouchHitSource }
        defer { touch = nil }
        var onsets: [TimeInterval] = []
        // Expected syllables from bar 2 (bar 1 is the count-in), once the click's beat 0 is known.
        func expected(from zero: TimeInterval) -> [(time: TimeInterval, label: String)] {
            let labels = Counting.labels(mode: mode, beats: 4)
            return (1...bars).flatMap { bar in labels.map { (zero + (Double(bar) * 4 + $0.position.doubleValue) * 60 / bpm, $0.label) } }
        }
        let collector = Task {
            for await h in source.hits {
                onsets.append(h.time); heard = onsets.count
                if judge == nil, let zero = metro.beatZeroHostTime { judge = CountJudge(expected: expected(from: zero), input: answer == .voice ? .voice : .tap) }
                if let m = judge?.hear(h.time) { lastMark = m }
            }
        }
        if stage == .fade {
            try? await Task.sleep(for: .seconds(barSeconds * 3))
            var quiet = s; quiet.voiceVolume = 0.2; metro.update(quiet)
            if !Task.isCancelled { try? await Task.sleep(for: .seconds(barSeconds * 2)) }
            quiet.voiceVolume = 0; metro.update(quiet)
            try? await Task.sleep(for: .seconds(barSeconds * Double(bars - 4) + 0.3))
        } else {
            try? await Task.sleep(for: .seconds(barSeconds * Double(bars + 1) + 0.3))
        }
        collector.cancel()
        let zero = metro.beatZeroHostTime
        let stoppedAt = HostClock.now()
        metro.stop(); source.stop()
        // Stopping early still scores what was counted so far.
        guard stage != .listen, let zero else { return }
        let all = expected(from: zero)
        var final = judge ?? CountJudge(expected: all, input: answer == .voice ? .voice : .tap)
        if judge == nil { for t in onsets { _ = final.hear(t) } }
        let scored = final.summary(until: stoppedAt)
        guard scored.onTime + scored.early + scored.late + scored.missed > 0 else { return }
        summary = scored
        let style = Counting.labels(mode: mode, beats: 1).map(\.label).map { $0.isEmpty ? "1" : $0 }.joined(separator: " ")
        SettingsStore.countRecords.append(CountRecord(date: Date(), phase: "\(stage)", style: style, bpm: bpm, summary: scored, input: answer == .voice ? .voice : .tap))
        let r = CountEvenness(onsets: onsets, expected: all.filter { $0.time < stoppedAt })
        result = r.matched > 0 ? r : nil
        if scored.onTime + scored.early + scored.late == 0 {
            error = switch answer {
            case .voice: L("Không nghe thấy tiếng đếm. Nói to hơn hoặc đưa iPad lại gần.", "Couldn't hear any counting. Speak louder or move the iPad closer.")
            case .table: L("Không nghe thấy tiếng gõ. Đặt iPad trên cùng mặt bàn, gõ mạnh hơn, hoặc tăng Độ nhạy micro trong Hiệu chỉnh.", "Couldn't hear any taps. Put the iPad on the same table, tap harder, or raise Mic sensitivity in Calibration.")
            case .screen: L("Chưa nhận được lần chạm nào.", "No taps received.")
            }
        }
    }
}
