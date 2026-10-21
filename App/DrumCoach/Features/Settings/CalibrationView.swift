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
    @State private var padSetup: PadProfileRecorder?
    @State private var padMessage: String?
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
                if mode == .pad { padSection }
                Section {
                    Text(L("Đang đo cho: \(AudioSessionConfig.outputName)", "Measuring for: \(AudioSessionConfig.outputName)")).foregroundStyle(.secondary)
                    Button(running ? L("Đang đo… (\(heard) cú)", "Measuring… (\(heard) hits)") : L("Bắt đầu đo", "Start measuring")) { Task { await measure() } }
                        .disabled(running)
                    if let mic { MicMeter(level: { mic.inputLevel }, lastHit: { mic.lastHitTime }) }
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

    /// Step 1 for the pad: 8 taps teach the app how loud the room is and what this pad sounds like.
    private var padSection: some View {
        Section {
            if let padSetup {
                TimelineView(.animation) { _ in
                    let hits = padSetup.hits
                    VStack(alignment: .leading, spacing: 10) {
                        Text(hits == 0 ? L("Im lặng một giây… rồi gõ 8 cái đều tay, có cả vài cú thật nhẹ.", "Stay quiet for a second… then tap 8 times, a few of them very soft.")
                                       : L("Đã nghe \(hits)/8 cú", "Heard \(hits)/8 taps"))
                        HStack(spacing: 10) {
                            ForEach(0..<PadProfiler.tapsNeeded, id: \.self) { i in
                                Circle().fill(i < hits ? Theme.onTime : Theme.hairline).frame(width: 18, height: 18)
                            }
                        }
                        MicMeter(level: { padSetup.inputLevel }, lastHit: { -.infinity })
                    }
                    .onChange(of: hits) { _, n in if n >= PadProfiler.tapsNeeded { finishPadSetup() } }
                }
                Button(L("Hủy", "Cancel"), role: .cancel) { padSetup.stop(); self.padSetup = nil }
            } else {
                Text(SettingsStore.padProfile.map { L("Đã chỉnh cho pad của bạn: nhận cú gõ từ \(String(format: "%.1f", $0.threshold * 100))% (tiếng nền \(String(format: "%.1f", $0.noiseFloor * 100))%).", "Tuned to your pad: strokes from \(String(format: "%.1f", $0.threshold * 100))% (room \(String(format: "%.1f", $0.noiseFloor * 100))%).") }
                     ?? L("Chưa chỉnh: đang dùng độ nhạy mặc định.", "Not tuned yet: using the default sensitivity."))
                    .foregroundStyle(.secondary)
                Button(L("Gõ thử 8 cái", "Tap 8 times")) { Task { await startPadSetup() } }
                    .disabled(running)
            }
            if let padMessage { Text(padMessage) }
        } header: {
            Text(L("Bước 1: Cho app làm quen pad", "Step 1: Let the app learn your pad"))
        } footer: {
            Text(L("Đặt iPad cách pad 30–50 cm, phòng yên tĩnh. App đo tiếng nền và tiếng dùi trên pad của bạn, để nghe được cả nốt ma mà không bắt nhầm tiếng nói.", "Put the iPad 30–50 cm from the pad in a quiet room. The app measures the room and your stick on this pad, so it hears ghost notes without picking up voices."))
        }
    }

    private func startPadSetup() async {
        padMessage = nil
        guard await MicPermission.ensure() else {
            padMessage = L("iPad đang chặn micro của DrumCoach. Vào Cài đặt của iPad → Quyền riêng tư & Bảo mật → Micrô rồi bật DrumCoach.", "The iPad is blocking DrumCoach's microphone. Go to iPad Settings → Privacy & Security → Microphone and turn DrumCoach on.")
            return
        }
        let recorder = PadProfileRecorder()
        do {
            try AudioSessionConfig.activate()
            try recorder.start()
        } catch {
            padMessage = L("Không mở được micro: \(error.localizedDescription)", "Couldn't open the microphone: \(error.localizedDescription)")
            return
        }
        padSetup = recorder
    }

    private func finishPadSetup() {
        guard let recorder = padSetup else { return }
        recorder.stop()
        padSetup = nil
        if let profile = recorder.profile {
            SettingsStore.padProfile = profile
            padMessage = L("Xong! Giờ làm Bước 2 để đo độ trễ.", "Done! Now do step 2 to measure latency.")
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
    let level: () -> Float
    let lastHit: () -> TimeInterval

    var body: some View {
        TimelineView(.animation) { _ in
            let level = Double(self.level())
            // Map −60…0 dBFS to 0…1 so quiet pads still move the bar.
            let fill = max(0, min(1, (20 * log10(max(level, 1e-6)) + 60) / 60))
            let flashing = HostClock.now() - lastHit() < 0.15
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
