import AVFoundation
import DrumAudio
import Foundation

/// Records the user's own counting syllables and keeps them in Documents/voice/<label>.f32.
@MainActor
final class VoiceRecorder: ObservableObject {
    @Published private(set) var recordingLabel: String?
    private let engine = AVAudioEngine()

    static let labels = ["1", "2", "3", "4", "e", "&", "a", "trip", "let"]
    private static var dir: URL {
        let d = URL.documentsDirectory.appending(path: "voice")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private static func file(_ label: String) -> URL { dir.appending(path: (label == "&" ? "and" : label) + ".f32") }

    static func hasRecording(_ label: String) -> Bool { FileManager.default.fileExists(atPath: file(label).path) }

    /// Load all saved recordings into the voice bank (called at launch).
    static func loadAll(into bank: CountVoiceBank) {
        for label in labels {
            guard let data = try? Data(contentsOf: file(label)) else { continue }
            let samples = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
            bank.setCustomSyllable(label, samples: samples)
        }
    }

    static func delete(_ label: String) { try? FileManager.default.removeItem(at: file(label)) }

    /// Record one second, resampled to the bank's rate, and save it.
    func record(_ label: String, into bank: CountVoiceBank) async throws {
        try AudioSessionConfig.activate()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let collector = SampleCollector()
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let ch = buffer.floatChannelData?[0] else { return }
            collector.append(Array(UnsafeBufferPointer(start: ch, count: Int(buffer.frameLength))))
        }
        recordingLabel = label
        try engine.start()
        try await Task.sleep(for: .seconds(1.2))
        input.removeTap(onBus: 0)
        engine.stop()
        recordingLabel = nil
        let raw = collector.samples
        let ratio = bank.sampleRate / format.sampleRate
        let resampled = (0..<Int(Double(raw.count) * ratio)).map { raw[min(raw.count - 1, Int(Double($0) / ratio))] }
        bank.setCustomSyllable(label, samples: resampled)
        if let shaped = bank.samples(for: label) {
            try shaped.withUnsafeBufferPointer { Data(buffer: $0) }.write(to: Self.file(label))
        }
    }
}

private final class SampleCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buf: [Float] = []
    func append(_ s: [Float]) { lock.withLock { buf += s } }
    var samples: [Float] { lock.withLock { buf } }
}
