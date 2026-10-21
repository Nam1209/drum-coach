import DrumAudio
import DrumCore
import SwiftUI

/// Stand-alone metronome screen (later embedded in the practice screen).
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
        VStack(spacing: 28) {
            HStack(spacing: 32) {
                roundButton("minus") { settings.bpm = max(30, settings.bpm - 1) }
                VStack(spacing: 0) {
                    Text("\(Int(settings.bpm))").font(.system(size: 96, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("BPM").font(.title3).foregroundStyle(.secondary)
                }
                .frame(minWidth: 200)
                roundButton("plus") { settings.bpm = min(300, settings.bpm + 1) }
            }
            Slider(value: $settings.bpm, in: 30...300, step: 1).frame(maxWidth: 500)
            HStack(spacing: 16) {
                Button(engine.isRunning ? "Dừng" : "Bắt đầu") { toggle() }
                    .buttonStyle(.borderedProminent).tint(.orange).controlSize(.large)
                Button("Tap tempo") { tapTempo() }.buttonStyle(.bordered).controlSize(.large)
                Button { showSheet = true } label: { Label("Âm thanh", systemImage: "slider.horizontal.3") }
                    .buttonStyle(.bordered).controlSize(.large)
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .padding()
        .sheet(isPresented: $showSheet) { MetronomeSheet(settings: $settings) }
        .onChange(of: settings) { _, new in
            SettingsStore.saveMetronome(new)
            if engine.isRunning { engine.update(new) }
        }
        .task { await voiceBank.prepare() }
    }

    private func roundButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title.bold()).frame(width: 72, height: 72)
                .background(Circle().fill(Color.orange)).foregroundStyle(.white)
        }
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
        settings.bpm = (60 / (intervals.reduce(0, +) / Double(intervals.count))).rounded()
    }
}
