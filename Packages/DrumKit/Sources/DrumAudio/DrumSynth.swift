import AVFoundation
import DrumCore
import Foundation

/// Simple synthesized drum kit for playing examples (ear tests, "nghe mẫu") without sample files.
public enum DrumSynth {
    public static func render(_ voice: Voice, sampleRate: Double, velocity: Float = 0.9) -> [Float] {
        var rng = SplitMix(seed: UInt64(abs(voice.hashValue) & 0xFFFF) | 1)
        func noise() -> Double { rng.nextUnit() * 2 - 1 }
        func make(length: Double, _ f: (Double) -> Double) -> [Float] {
            let n = Int(length * sampleRate)
            var out = (0..<n).map { i -> Float in Float(f(Double(i) / sampleRate)) }
            let fade = min(n, Int(0.005 * sampleRate))
            for i in 0..<fade { out[n - 1 - i] *= Float(i) / Float(max(fade, 1)) }
            let peak = out.map(abs).max() ?? 1
            return peak > 0 ? out.map { $0 / peak * velocity } : out
        }
        switch voice {
        case .kick:
            return make(length: 0.35) { t in sin(2 * .pi * (50 * t + 60 * (1 - exp(-t / 0.03)) * 0.03)) * exp(-t / 0.12) }
        case .snare, .sideStick:
            let tone = voice == .snare ? 0.5 : 0.8
            return make(length: voice == .snare ? 0.25 : 0.08) { t in
                (tone * sin(2 * .pi * 190 * t) + (1 - tone) * noise()) * exp(-t / (voice == .snare ? 0.06 : 0.015))
            }
        case .tom1, .tom2, .floorTom:
            let f = voice == .tom1 ? 200.0 : voice == .tom2 ? 150 : 100
            return make(length: 0.4) { t in sin(2 * .pi * f * t * (1 + 0.3 * exp(-t / 0.05))) * exp(-t / 0.15) }
        case .hiHat, .hiHatPedal:
            return make(length: 0.06) { t in noise() * exp(-t / 0.012) }
        case .hiHatOpen:
            return make(length: 0.35) { t in noise() * exp(-t / 0.12) }
        case .ride:
            return make(length: 0.6) { t in (0.6 * sin(2 * .pi * 3_100 * t) + 0.4 * noise()) * exp(-t / 0.25) }
        case .crash:
            return make(length: 1.2) { t in noise() * exp(-t / 0.45) }
        }
    }

    /// Mono audio of `exercise` at `bpm` (with `swing`, as the metronome plays it), preceded by `countInBars` of clicks on the beats.
    public static func renderPattern(_ exercise: Exercise, bpm: Double, countInBars: Int, sampleRate: Double, swing: Double = Swing.straight) -> [Float] {
        let timeline = Timeline(exercise: exercise, bpm: bpm, repeats: 1, countInBars: countInBars, swing: swing)
        var out = [Float](repeating: 0, count: Int((timeline.duration * sampleRate).rounded()))
        func mix(_ s: [Float], at t: Double, gain: Float = 1) {
            let start = Int((t * sampleRate).rounded())
            for (i, v) in s.enumerated() where start + i < out.count { out[start + i] += v * gain }
        }
        let beatSeconds = 60 / bpm * 4 / Double(exercise.timeSignature.unit)
        for b in 0..<(countInBars * exercise.timeSignature.beats) { mix(render(.sideStick, sampleRate: sampleRate, velocity: 0.6), at: Double(b) * beatSeconds) }
        for n in timeline.notes {
            let gain: Float = n.note.articulation == .accent ? 1 : n.note.articulation == .ghost ? 0.35 : 0.75
            mix(render(n.note.voice, sampleRate: sampleRate), at: n.time, gain: gain)
            if n.note.articulation == .flam { mix(render(n.note.voice, sampleRate: sampleRate), at: max(0, n.time - 0.025), gain: 0.3) }
            if n.note.articulation == .drag {
                for k in [0.06, 0.035] { mix(render(n.note.voice, sampleRate: sampleRate), at: max(0, n.time - k), gain: 0.3) }
            }
        }
        return out.map { max(-1, min(1, $0)) }
    }
}

/// Plays rendered drum audio (ear-test prompts, "nghe mẫu").
@MainActor
public final class DrumPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    public func play(_ exercise: Exercise, bpm: Double, countInBars: Int = 1, swing: Double = Swing.straight) throws {
        let samples = DrumSynth.renderPattern(exercise, bpm: bpm, countInBars: countInBars, sampleRate: 48_000, swing: swing)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        if !engine.isRunning { try engine.start() }
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    public func stop() { player.stop() }
}
