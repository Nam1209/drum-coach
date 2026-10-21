import DrumAnalysis
import DrumAudio
import DrumCore
import SwiftUI

/// Measures the remaining latency of the chosen input by having the player hit along with 16 clicks.
struct CalibrationView: View {
    let voiceBank: CountVoiceBank
    @State private var mode: InputMode = .pad
    @State private var running = false
    @State private var heard = 0
    @State private var message: String?
    @State private var engine: MetronomeEngine?
    @Environment(\.dismiss) private var dismiss

    private let run = CalibrationRun()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Thiết bị", selection: $mode) {
                        Text(InputMode.pad.title).tag(InputMode.pad)
                        Text(InputMode.eDrum.title).tag(InputMode.eDrum)
                    }
                    .pickerStyle(.segmented)
                    .disabled(running)
                    Text("Hiện tại: \(Int((SettingsStore.latency(for: mode) * 1000).rounded())) ms")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text(mode == .pad
                         ? "Đeo tai nghe. Sau 4 tiếng đếm vào, gõ pad đúng theo 16 tiếng click. Hoặc bỏ tai nghe, đặt iPad cạnh loa và để micro tự nghe click."
                         : "Cắm cáp USB-MIDI từ MIDI OUT của TD-7. Sau 4 tiếng đếm vào, đánh snare đúng theo 16 tiếng click.")
                }
                Section {
                    Button(running ? "Đang đo… (\(heard) cú)" : "Bắt đầu đo") { Task { await measure() } }
                        .disabled(running)
                    if let message { Text(message) }
                }
            }
            .navigationTitle("Hiệu chỉnh độ trễ")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
        }
    }

    private func measure() async {
        guard let source = HitSources.make(for: mode, calibrated: false) else { return }
        running = true; heard = 0; message = nil
        defer { running = false }
        let metro = MetronomeEngine(voiceBank: voiceBank)
        engine = metro
        do {
            try AudioSessionConfig.activate()
            try source.start()
            try metro.start(settings: MetronomeSettings(bpm: run.bpm, pattern: .quarter, accentBeatOne: true))
        } catch {
            message = "Không mở được âm thanh/MIDI: \(error.localizedDescription)"
            source.stop(); metro.stop()
            return
        }
        var detected: [TimeInterval] = []
        let collector = Task {
            for await hit in source.hits { detected.append(hit.time); heard = detected.count }
        }
        try? await Task.sleep(for: .seconds(run.duration + 0.6))
        collector.cancel()
        let zero = metro.beatZeroHostTime
        metro.stop(); source.stop()
        guard let zero, let estimate = LatencyCalibrator.estimate(expected: run.expected(beatZero: zero), detected: detected) else {
            message = "Kết quả chưa ổn định (\(detected.count) cú nghe được). Thử lại và đánh đều theo click nhé."
            return
        }
        SettingsStore.setLatency(estimate, for: mode)
        message = "Đã lưu: \(Int((estimate * 1000).rounded())) ms"
    }
}
