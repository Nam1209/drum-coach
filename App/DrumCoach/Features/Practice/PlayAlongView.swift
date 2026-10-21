import DrumAudio
import SwiftUI
import UniformTypeIdentifiers

/// Play along with a song or backing track: change tempo without changing pitch, loop a section A–B.
struct PlayAlongView: View {
    @StateObject private var player = BackingTrackPlayer()
    @State private var importing = false
    @State private var name: String?
    @State private var originalBpm: Double = 100
    @State private var targetBpm: Double = 100
    @State private var loop = false
    @State private var a: Double = 0
    @State private var b: Double = 10
    @State private var volume: Float = 0.8
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                Button(name ?? "Chọn file nhạc…") { importing = true }
                Text("Ví dụ: backing track của bài trong sách (khi bạn có bản chính hãng) hoặc bất kỳ bài hát nào.").font(.caption).foregroundStyle(.secondary)
            }
            if name != nil {
                Section("Tempo") {
                    Stepper("Tempo gốc của bài: \(Int(originalBpm))", value: $originalBpm, in: 40...240)
                    Stepper("Tempo tập: \(Int(targetBpm)) (\(Int(Double(BackingTrackPlan.rate(targetBpm: targetBpm, originalBpm: originalBpm)) * 100))%)",
                            value: $targetBpm, in: 30...240)
                    Slider(value: $volume, in: 0...1) { Text("Âm lượng") }
                }
                Section("Lặp đoạn A–B") {
                    Toggle("Bật lặp", isOn: $loop)
                    if loop {
                        Slider(value: $a, in: 0...max(1, player.duration)) { Text("A") }
                        Text("A: \(fmt(a))")
                        Slider(value: $b, in: 0...max(1, player.duration)) { Text("B") }
                        Text("B: \(fmt(b))")
                    }
                }
                Button(player.isPlaying ? "Dừng" : "Phát") { toggle() }.buttonStyle(.borderedProminent)
                if let error { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Chơi theo nhạc")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            guard let url = try? result.get() else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            // Copy into the app so the file stays readable.
            let local = URL.documentsDirectory.appending(path: "Tracks/\(url.lastPathComponent)")
            try? FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: local)
            do {
                try FileManager.default.copyItem(at: url, to: local)
                try player.load(local)
                name = url.lastPathComponent
                b = player.duration
            } catch { self.error = "Không mở được file: \(error.localizedDescription)" }
        }
        .onDisappear { player.stop() }
    }

    private func toggle() {
        if player.isPlaying { player.stop(); return }
        do {
            try AudioSessionConfig.activate()
            try player.play(rate: BackingTrackPlan.rate(targetBpm: targetBpm, originalBpm: originalBpm),
                            loopA: loop ? a : nil, loopB: loop ? b : nil, volume: volume)
            error = nil
        } catch BackingTrackPlan.LoopError.badRange {
            error = "Điểm A phải trước điểm B."
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func fmt(_ t: Double) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }
}
