import DrumAudio
import DrumCore
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
                Button(name ?? L("Chọn file nhạc…", "Choose a music file…")) { importing = true }
                Text(L("Ví dụ: backing track của bài trong sách (khi bạn có bản chính hãng) hoặc bất kỳ bài hát nào.", "For example: the backing track of a book exercise (if you own the original) or any song.")).font(.caption).foregroundStyle(.secondary)
            }
            if name != nil {
                Section("Tempo") {
                    Stepper(L("Tempo gốc của bài: \(Int(originalBpm))", "Original tempo: \(Int(originalBpm))"), value: $originalBpm, in: 40...240)
                    Stepper(L("Tempo tập: \(Int(targetBpm)) (\(Int(Double(BackingTrackPlan.rate(targetBpm: targetBpm, originalBpm: originalBpm)) * 100))%)", "Practice tempo: \(Int(targetBpm)) (\(Int(Double(BackingTrackPlan.rate(targetBpm: targetBpm, originalBpm: originalBpm)) * 100))%)"),
                            value: $targetBpm, in: 30...240)
                    Slider(value: $volume, in: 0...1) { Text(L("Âm lượng", "Volume")) }
                }
                Section(L("Lặp đoạn A–B", "Loop section A–B")) {
                    Toggle(L("Bật lặp", "Loop on"), isOn: $loop)
                    if loop {
                        Slider(value: $a, in: 0...max(1, player.duration)) { Text("A") }
                        Text("A: \(fmt(a))")
                        Slider(value: $b, in: 0...max(1, player.duration)) { Text("B") }
                        Text("B: \(fmt(b))")
                    }
                }
                Button(player.isPlaying ? L("Dừng", "Stop") : L("Phát", "Play")) { toggle() }.buttonStyle(.borderedProminent)
                if let error { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle(L("Chơi theo nhạc", "Play along"))
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
            } catch { self.error = L("Không mở được file: \(error.localizedDescription)", "Couldn't open file: \(error.localizedDescription)") }
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
            error = L("Điểm A phải trước điểm B.", "Point A must come before point B.")
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func fmt(_ t: Double) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }
}
