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
            case .listen: "1. Nghe"
            case .along: "2. Đếm cùng"
            case .fade: "3. Giọng nhỏ dần"
            case .alone: "4. Tự đếm"
            }
        }
        var hint: String {
            switch self {
            case .listen: "Chỉ nghe app đếm. Để ý \"&\" nằm đúng giữa hai số."
            case .along: "Đeo tai nghe, nói to và liền hơi cùng app, như một câu hát."
            case .fade: "Giọng app nhỏ dần rồi tắt sau 4 ô nhịp. Bạn giữ nguyên nhịp đếm."
            case .alone: "Chỉ còn click, và click tắt 2 ô nhịp xen kẽ. Bạn tự đếm đều."
            }
        }
    }

    let voiceBank: CountVoiceBank
    @State private var stage: Phase = .listen
    @State private var mode: CountMode = .eighths
    @State private var bpm: Double = 60
    @State private var run: Task<Void, Never>?
    @State private var result: CountEvenness?
    @State private var heard = 0
    @State private var error: String?
    @State private var engine: MetronomeEngine?

    private let bars = 8
    private var running: Bool { run != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Đếm nhịp", subtitle: "Đếm to theo click. App nghe giọng bạn và đo độ đều của từng âm.")
                Stage {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("Giai đoạn", selection: $stage) { ForEach(Phase.allCases) { Text($0.title).tag($0) } }
                            .pickerStyle(.segmented)
                        Text(stage.hint).foregroundStyle(.secondary)
                        Picker("Cách đếm", selection: $mode) {
                            Text("1 2 3 4").tag(CountMode.quarters)
                            Text("1 & 2 &").tag(CountMode.eighths)
                            Text("1 e & a").tag(CountMode.sixteenths)
                            Text("1 trip let").tag(CountMode.triplets)
                        }
                        .pickerStyle(.segmented)
                        syllables
                        HStack(spacing: 28) {
                            PlayButton(isPlaying: running) { running ? stop() : start() }
                            TempoControl(bpm: $bpm, range: 40...120, disabled: running)
                            Spacer()
                            Readout(value: running ? "\(heard)" : result.map { "\(Int((max(0, 1 - $0.gapRatioStdDev) * 100).rounded()))%" } ?? "–",
                                    caption: running ? "âm đã nghe" : "độ đều", size: 44)
                        }
                    }
                }
                        if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Theme.missed) }
                if let result { resultView(result) }
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

    private func resultView(_ r: CountEvenness) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kết quả").font(.title3.weight(.semibold))
            labelRow(r)
            Text(advice(r)).font(.headline)
            Text(String(format: "Độ lệch giữa các khoảng: %.0f%% (càng gần 0%% càng đều).", r.gapRatioStdDev * 100))
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func labelRow(_ r: CountEvenness) -> some View {
        HStack(spacing: 10) {
            ForEach(r.offsetsByLabel.sorted { $0.key < $1.key }, id: \.key) { label, ms in
                VStack {
                    Text(label == "number" ? "số" : label).font(Theme.number(24))
                    Text(String(format: "%+.0f ms", ms)).font(Theme.number(13, weight: .medium))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill((abs(ms) <= 25 ? Theme.onTime : Theme.offTime).opacity(0.16)))
            }
        }
    }

    private func advice(_ r: CountEvenness) -> String {
        guard let (label, ms) = r.offsetsByLabel.filter({ $0.key != "number" }).max(by: { abs($0.value) < abs($1.value) }),
              abs(ms) > 25 else { return "Rất đều! Thử giai đoạn tiếp theo hoặc tăng tempo 4 BPM." }
        return ms > 0
            ? "Bạn nói \"\(label)\" trễ trung bình \(Int(ms.rounded())) ms → nghĩ \"\(label)\" nằm ĐÚNG giữa hai phách, nói sớm hơn một chút."
            : "Bạn nói \"\(label)\" sớm \(Int((-ms).rounded())) ms → đừng vội, chờ đúng giữa hai phách."
    }

    private func start() {
        run = Task { await go(); run = nil; engine = nil }
    }

    private func stop() {
        run?.cancel()
    }

    private func go() async {
        result = nil; heard = 0; error = nil
        var s = MetronomeSettings(bpm: bpm, pattern: .quarter, accentBeatOne: true, voiceCount: mode)
        switch stage {
        case .listen, .along: s.voiceVolume = 1
        case .fade: s.voiceVolume = 0.5
        case .alone: s.voiceCount = nil; s.gap = GapPattern(playBars: 2, muteBars: 2)
        }
        let metro = MetronomeEngine(voiceBank: voiceBank)
        engine = metro
        let barSeconds = 4 * 60 / bpm
        let mic = MicOnsetSource(calibrationOffset: SettingsStore.latency(for: .pad)) { SyllableOnsetDetector(sampleRate: $0) }
        do {
            try AudioSessionConfig.activate()
            if stage != .listen { try mic.start() }
            try metro.start(settings: s)
        } catch {
            self.error = "Không mở được âm thanh: \(error.localizedDescription)"
            mic.stop()
            return
        }
        var onsets: [TimeInterval] = []
        let collector = Task { for await h in mic.hits { onsets.append(h.time); heard = onsets.count } }
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
        metro.stop(); mic.stop()
        guard !Task.isCancelled, stage != .listen, let zero else { return }
        // Expected syllables from bar 2 (bar 1 is the count-in).
        var expected: [(time: TimeInterval, label: String)] = []
        let labels = Counting.labels(mode: mode, beats: 4)
        for bar in 1...bars {
            for l in labels { expected.append((zero + (Double(bar) * 4 + l.position.doubleValue) * 60 / bpm, l.label)) }
        }
        let r = CountEvenness(onsets: onsets, expected: expected)
        result = r.matched > 0 ? r : nil
        if result == nil { error = "Không nghe thấy tiếng đếm. Nói to hơn hoặc đưa iPad lại gần." }
    }
}
