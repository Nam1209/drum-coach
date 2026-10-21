import DrumAnalysis
import DrumAudio
import DrumCore
import SwiftUI

/// Practise counting out loud evenly: listen → count along → the voice fades → count alone with a gapped click.
struct CountCoachView: View {
    enum Stage: Int, CaseIterable, Identifiable {
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
    @State private var stage: Stage = .listen
    @State private var mode: CountMode = .eighths
    @State private var bpm: Double = 60
    @State private var running = false
    @State private var result: CountEvenness?
    @State private var heard = 0
    @State private var error: String?
    @State private var engine: MetronomeEngine?

    private let bars = 8

    var body: some View {
        Form {
            Section {
                Picker("Giai đoạn", selection: $stage) { ForEach(Stage.allCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                Text(stage.hint).foregroundStyle(.secondary)
                Picker("Cách đếm", selection: $mode) {
                    Text("1 2 3 4").tag(CountMode.quarters)
                    Text("1 & 2 &").tag(CountMode.eighths)
                    Text("1 e & a").tag(CountMode.sixteenths)
                    Text("1 trip let").tag(CountMode.triplets)
                }
                Stepper("Tempo: \(Int(bpm)) BPM", value: $bpm, in: 40...120, step: 2)
            }
            .disabled(running)
            Section {
                Button(running ? "Đang chạy… (nghe được \(heard) âm)" : "Bắt đầu \(bars) ô nhịp") { Task { await go() } }
                    .disabled(running)
                if let error { Text(error).foregroundStyle(.red) }
            }
            if let result {
                Section("Kết quả") {
                    labelRow(result)
                    Text(String(format: "Độ đều giữa các âm: %.0f%% (càng gần 0%% càng đều)", result.gapRatioStdDev * 100))
                    Text(advice(result)).bold()
                }
            }
        }
        .navigationTitle("Count Coach")
    }

    private func labelRow(_ r: CountEvenness) -> some View {
        HStack(spacing: 10) {
            ForEach(r.offsetsByLabel.sorted { $0.key < $1.key }, id: \.key) { label, ms in
                VStack {
                    Text(label == "number" ? "số" : label).font(.title2.bold())
                    Text(String(format: "%+.0f ms", ms)).font(.caption).monospacedDigit()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill((abs(ms) <= 25 ? Color.green : .orange).opacity(0.25)))
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

    private func go() async {
        running = true; result = nil; heard = 0; error = nil
        defer { running = false }
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
            return
        }
        var onsets: [TimeInterval] = []
        let collector = Task { for await h in mic.hits { onsets.append(h.time); heard = onsets.count } }
        if stage == .fade {
            try? await Task.sleep(for: .seconds(barSeconds * 3))
            var quiet = s; quiet.voiceVolume = 0.2; metro.update(quiet)
            try? await Task.sleep(for: .seconds(barSeconds * 2))
            quiet.voiceVolume = 0; metro.update(quiet)
            try? await Task.sleep(for: .seconds(barSeconds * Double(bars - 4) + 0.3))
        } else {
            try? await Task.sleep(for: .seconds(barSeconds * Double(bars + 1) + 0.3))
        }
        collector.cancel()
        let zero = metro.beatZeroHostTime
        metro.stop(); mic.stop()
        guard stage != .listen, let zero else { return }
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
