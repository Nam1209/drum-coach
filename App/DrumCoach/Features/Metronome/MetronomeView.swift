import DrumAudio
import DrumCore
import SwiftUI

/// Stand-alone metronome: one big tempo, the beats of the bar, and the pulsing play button.
struct MetronomeView: View {
    @StateObject private var engine: MetronomeEngine
    @State private var settings: MetronomeSettings
    @State private var showSheet = false
    @State private var taps: [Date] = []
    @State private var error: String?
    private let voiceBank: CountVoiceBank

    init(voiceBank: CountVoiceBank) {
        self.voiceBank = voiceBank
        let saved = SettingsStore.loadMetronome() ?? MetronomeSettings(bpm: 70, pattern: .eighths, accentBeatOne: true)
        _settings = State(initialValue: saved)
        _engine = StateObject(wrappedValue: MetronomeEngine(voiceBank: voiceBank, settings: saved))
    }

    var body: some View {
        TimelineView(.animation(paused: !engine.isRunning)) { _ in
            let beat = currentBeat()
            VStack(spacing: 36) {
                PageHeader(title: "Máy nhịp", subtitle: summary) {
                    Button { showSheet = true } label: {
                        Label("Âm thanh", systemImage: "slider.horizontal.3").padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(Theme.stage))
                    }
                }
                Spacer()
                beats(beat)
                VStack(spacing: 4) {
                    Text("\(Int(settings.bpm))").font(Theme.number(150, weight: .bold)).contentTransition(.numericText())
                    Text("BPM").font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 40) {
                    roundStep("minus") { settings.bpm = max(30, settings.bpm - 1) }
                    PlayButton(isPlaying: engine.isRunning, beatPhase: beat.map { $0 - floor($0) } ?? 0, size: 104) { toggle() }
                    roundStep("plus") { settings.bpm = min(300, settings.bpm + 1) }
                }
                Slider(value: $settings.bpm, in: 30...300, step: 1).frame(maxWidth: 520)
                Button("Gõ để lấy tempo") { tapTempo() }.font(.callout.weight(.medium))
                if let error { Text(error).foregroundStyle(Theme.missed) }
                Spacer()
            }
            .padding(Theme.pagePadding)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas)
        .sheet(isPresented: $showSheet) { MetronomeSheet(settings: $settings) }
        .onChange(of: settings) { _, new in
            SettingsStore.saveMetronome(new)
            if engine.isRunning { engine.update(new) }
        }
        .onDisappear { engine.stop() }
    }

    /// The beats of one bar; the current one lights up.
    private func beats(_ beat: Double?) -> some View {
        let n = settings.timeSignature.beats
        let current = beat.map { Int(floor($0)) % n }
        return HStack(spacing: 14) {
            ForEach(0..<n, id: \.self) { i in
                Circle()
                    .fill(current == i ? (i == 0 ? Theme.shell : Color.primary) : Theme.hairline)
                    .frame(width: i == 0 ? 22 : 16, height: i == 0 ? 22 : 16)
            }
        }
        .frame(height: 24)
        .animation(.easeOut(duration: 0.08), value: current)
    }

    private var summary: String {
        var parts = ["\(settings.timeSignature.beats)/\(settings.timeSignature.unit)"]
        let names: [(ClickPattern, String)] = [(.quarter, "click nốt đen"), (.eighths, "click móc đơn"), (.sixteenths, "click móc kép"),
                                                (.triplets, "click chùm ba"), (.offbeat, "click phách lẻ")]
        parts.append(names.first { $0.0 == settings.pattern }?.1 ?? "click tùy chỉnh")
        if settings.voiceCount != nil { parts.append("có giọng đếm") }
        if settings.gap != nil { parts.append("có gap") }
        return parts.joined(separator: ", ")
    }

    private func currentBeat() -> Double? {
        guard engine.isRunning, let zero = engine.beatZeroHostTime else { return nil }
        let t = HostClock.now() - zero
        return t < 0 ? nil : t / settings.secondsPerBeat
    }

    private func roundStep(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title2.weight(.semibold)).frame(width: 64, height: 64)
                .background(Circle().fill(Theme.stage))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }

    private func toggle() {
        if engine.isRunning { engine.stop(); return }
        do {
            try AudioSessionConfig.activate()
            try engine.start(settings: settings)
            error = nil
        } catch {
            self.error = "Không mở được âm thanh: \(error.localizedDescription)"
        }
    }

    private func tapTempo() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 3 } + [now]
        guard taps.count >= 3 else { return }
        let intervals = zip(taps, taps.dropFirst()).map { $1.timeIntervalSince($0) }
        settings.bpm = min(300, max(30, (60 / (intervals.reduce(0, +) / Double(intervals.count))).rounded()))
    }
}
