import AVFoundation
import Foundation

/// Pre-rendered spoken counting syllables ("1"…"12", "e", "&", "a", "trip", "let") as mono Float samples.
public final class CountVoiceBank: @unchecked Sendable {
    public let sampleRate: Double
    private let lock = NSLock()
    private var syllables: [String: [Float]] = [:]

    static let spoken: [String: String] = [
        "1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "6": "six", "7": "seven",
        "8": "eight", "9": "nine", "10": "ten", "11": "eleven", "12": "twelve",
        "e": "ee", "&": "and", "a": "uh", "trip": "trip", "let": "let",
    ]

    public init(sampleRate: Double = 48_000) { self.sampleRate = sampleRate }

    /// Ratio (≤ 1) to speed a syllable up so it ends within 90% of its slot instead of being cut off.
    public static func stretchFactor(syllableDuration: TimeInterval, slot: TimeInterval) -> Double {
        guard syllableDuration > 0 else { return 1 }
        return min(1, 0.9 * slot / syllableDuration)
    }

    public func samples(for label: String) -> [Float]? {
        lock.lock(); defer { lock.unlock() }
        return syllables[label]
    }

    /// Replace a syllable with the user's own recording (mono, at `sampleRate`).
    public func setCustomSyllable(_ label: String, samples: [Float]) {
        let shaped = Self.shape(samples, sampleRate: sampleRate)
        lock.lock(); syllables[label] = shaped; lock.unlock()
    }

    /// Syllable fitted to `slot` seconds: sped up by linear resampling when too long, never truncated.
    public func fitted(_ label: String, slot: TimeInterval) -> [Float]? {
        guard let s = samples(for: label) else { return nil }
        let factor = Self.stretchFactor(syllableDuration: Double(s.count) / sampleRate, slot: slot)
        guard factor < 1 else { return s }
        let outCount = max(1, Int(Double(s.count) * factor))
        let step = Double(s.count - 1) / Double(max(outCount - 1, 1))
        return (0..<outCount).map { i in
            let x = Double(i) * step, j = Int(x), frac = Float(x - Double(j))
            return j + 1 < s.count ? s[j] * (1 - frac) + s[j + 1] * frac : s[j]
        }
    }

    /// Render every syllable with the system speech synthesizer. Missing voices are simply skipped.
    @MainActor
    public func prepare() async {
        let synth = AVSpeechSynthesizer()
        for (label, text) in Self.spoken where samples(for: label) == nil {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.55
            let raw = await Self.renderSpeech(synth, utterance, targetRate: sampleRate)
            guard !raw.isEmpty else { continue }
            let shaped = Self.shape(raw, sampleRate: sampleRate)
            lock.withLock { syllables[label] = shaped }
        }
    }

    /// Trim leading/trailing silence, 3 ms fade-in, 15 ms fade-out.
    static func shape(_ input: [Float], sampleRate: Double) -> [Float] {
        let threshold: Float = 0.02
        guard let first = input.firstIndex(where: { abs($0) > threshold }),
              let last = input.lastIndex(where: { abs($0) > threshold }) else { return [] }
        var s = Array(input[first...last])
        let fadeIn = min(Int(0.003 * sampleRate), s.count), fadeOut = min(Int(0.015 * sampleRate), s.count)
        for i in 0..<fadeIn { s[i] *= Float(i) / Float(max(fadeIn, 1)) }
        for i in 0..<fadeOut { s[s.count - 1 - i] *= Float(i) / Float(max(fadeOut, 1)) }
        return s
    }

    @MainActor
    private static func renderSpeech(_ synth: AVSpeechSynthesizer, _ u: AVSpeechUtterance, targetRate: Double) async -> [Float] {
        await withCheckedContinuation { (cont: CheckedContinuation<[Float], Never>) in
            let collector = SpeechCollector(targetRate: targetRate, continuation: cont)
            synth.write(u) { buffer in collector.append(buffer) }
        }
    }
}

/// Accumulates AVSpeechSynthesizer output buffers, resampled to mono Float at `targetRate`.
private final class SpeechCollector: @unchecked Sendable {
    let targetRate: Double
    var samples: [Float] = []
    var continuation: CheckedContinuation<[Float], Never>?

    init(targetRate: Double, continuation: CheckedContinuation<[Float], Never>) {
        self.targetRate = targetRate
        self.continuation = continuation
    }

    func append(_ buffer: AVAudioBuffer) {
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        if pcm.frameLength == 0 {
            continuation?.resume(returning: samples)
            continuation = nil
            return
        }
        let rate = pcm.format.sampleRate
        var mono: [Float] = []
        if let f = pcm.floatChannelData {
            mono = Array(UnsafeBufferPointer(start: f[0], count: Int(pcm.frameLength)))
        } else if let i = pcm.int16ChannelData {
            mono = UnsafeBufferPointer(start: i[0], count: Int(pcm.frameLength)).map { Float($0) / 32768 }
        }
        guard rate > 0, !mono.isEmpty else { return }
        let ratio = targetRate / rate
        let outCount = Int(Double(mono.count) * ratio)
        for k in 0..<outCount {
            let x = Double(k) / ratio, j = Int(x)
            samples.append(j < mono.count ? mono[j] : 0)
        }
    }
}
