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
    @State private var mic: MicOnsetSource?
    @Environment(\.dismiss) private var dismiss

    private let run = CalibrationRun()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("Thiết bị", "Device"), selection: $mode) {
                        Text(InputMode.pad.title).tag(InputMode.pad)
                        Text(InputMode.eDrum.title).tag(InputMode.eDrum)
                    }
                    .pickerStyle(.segmented)
                    .disabled(running)
                    Text(L("Hiện tại: \(Int((SettingsStore.latency(for: mode) * 1000).rounded())) ms", "Current: \(Int((SettingsStore.latency(for: mode) * 1000).rounded())) ms"))
                        .foregroundStyle(.secondary)
                } footer: {
                    Text(mode == .pad
                         ? L("Đeo tai nghe. Sau 4 tiếng đếm vào, gõ pad đúng theo 16 tiếng click. Hoặc bỏ tai nghe, đặt iPad cạnh loa và để micro tự nghe click.", "Wear headphones. After the 4 count-in clicks, hit the pad in time with the 16 clicks. Or take the headphones off, put the iPad next to the speaker and let the mic hear the click.")
                         : L("Cắm cáp USB-MIDI từ MIDI OUT của TD-4K. Sau 4 tiếng đếm vào, đánh snare đúng theo 16 tiếng click.", "Connect a USB-MIDI cable from the TD-4K MIDI OUT. After the 4 count-in clicks, hit the snare in time with the 16 clicks."))
                }
                Section {
                    Button(running ? L("Đang đo… (\(heard) cú)", "Measuring… (\(heard) hits)") : L("Bắt đầu đo", "Start measuring")) { Task { await measure() } }
                        .disabled(running)
                    if let mic { MicMeter(source: mic) }
                    if let message { Text(message) }
                } footer: {
                    if mode == .pad {
                        Text(L("Thanh xanh là mức micro đang nghe. Mỗi cú gõ phải làm thanh nhảy lên và chấm tròn nháy. Không nháy thì đặt iPad gần pad hơn hoặc gõ mạnh hơn.", "The bar is what the mic hears. Each stroke should make it jump and the dot flash. If it doesn't, move the iPad closer to the pad or hit harder."))
                    }
                }
            }
            .navigationTitle(L("Hiệu chỉnh độ trễ", "Latency calibration"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Xong", "Done")) { dismiss() } } }
        }
    }

    private func measure() async {
        if mode == .pad, !(await MicPermission.ensure()) {
            message = L("iPad đang chặn micro của DrumCoach. Vào Cài đặt của iPad → Quyền riêng tư & Bảo mật → Micrô rồi bật DrumCoach.", "The iPad is blocking DrumCoach's microphone. Go to iPad Settings → Privacy & Security → Microphone and turn DrumCoach on.")
            return
        }
        guard let source = HitSources.make(for: mode, calibrated: false) else { return }
        running = true; heard = 0; message = nil
        mic = source as? MicOnsetSource
        defer { running = false }
        let metro = MetronomeEngine(voiceBank: voiceBank)
        engine = metro
        do {
            try AudioSessionConfig.activate()
            try source.start()
            try metro.start(settings: MetronomeSettings(bpm: run.bpm, pattern: .quarter, accentBeatOne: true))
        } catch {
            message = L("Không mở được âm thanh/MIDI: \(error.localizedDescription)", "Couldn't open audio/MIDI: \(error.localizedDescription)")
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
        mic = nil
        guard let zero, let estimate = LatencyCalibrator.estimate(expected: run.expected(beatZero: zero), detected: detected) else {
            message = L("Kết quả chưa ổn định (\(detected.count) cú nghe được). Thử lại và đánh đều theo click nhé.", "Result isn't stable (\(detected.count) hits heard). Try again and play steadily with the click.")
            return
        }
        SettingsStore.setLatency(estimate, for: mode)
        message = L("Đã lưu: \(Int((estimate * 1000).rounded())) ms", "Saved: \(Int((estimate * 1000).rounded())) ms")
    }
}

/// Live microphone level with a dot that flashes on every detected stroke.
struct MicMeter: View {
    let source: MicOnsetSource

    var body: some View {
        TimelineView(.animation) { _ in
            let level = Double(source.inputLevel)
            // Map −60…0 dBFS to 0…1 so quiet pads still move the bar.
            let fill = max(0, min(1, (20 * log10(max(level, 1e-6)) + 60) / 60))
            let flashing = HostClock.now() - source.lastHitTime < 0.15
            HStack(spacing: 12) {
                Circle().fill(flashing ? Theme.onTime : Theme.hairline).frame(width: 14, height: 14)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.hairline)
                        Capsule().fill(Theme.onTime).frame(width: geo.size.width * fill)
                    }
                }
                .frame(height: 10)
                Text(L("Micro", "Mic")).font(.footnote).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Mức micro", "Microphone level"))
        }
    }
}
