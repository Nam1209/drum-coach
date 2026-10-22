import Foundation
import Testing
@testable import DrumAnalysis

/// Room noise at `noise`, then bright stick-on-pad strokes (a 5 ms burst of noise) peaking at `amps`, 0.5 s apart from 1 s.
private func taps(_ amps: [Float], noise: Float = 0.002, sr: Double = 48_000) -> [Float] {
    var rng = SystemRandomNumberGenerator()
    var out = (0..<Int((1.5 + Double(amps.count) * 0.5) * sr)).map { _ in Float.random(in: -noise...noise, using: &rng) }
    for (k, a) in amps.enumerated() {
        let start = Int((1 + Double(k) * 0.5) * sr)
        for i in 0..<Int(0.03 * sr) where start + i < out.count {
            out[start + i] += a * Float.random(in: -1...1, using: &rng) * Float(exp(-Double(i) / sr / 0.005))
        }
    }
    return out
}

/// Loud low "voice-like" bursts (250 Hz, 80 ms) at the same times.
private func hums(count: Int, amp: Float = 0.2, sr: Double = 48_000) -> [Float] {
    var out = [Float](repeating: 0, count: Int((1.5 + Double(count) * 0.5) * sr))
    for k in 0..<count {
        let start = Int((1 + Double(k) * 0.5) * sr)
        for i in 0..<Int(0.08 * sr) where start + i < out.count {
            let t = Double(i) / sr
            out[start + i] += amp * Float(sin(2 * .pi * 250 * t) * min(1, t / 0.01))
        }
    }
    return out
}

private func profile(_ s: [Float]) -> PadProfiler {
    var p = PadProfiler(sampleRate: 48_000)
    var i = 0
    while i < s.count { let e = min(i + 256, s.count); p.process(Array(s[i..<e])); i = e }
    return p
}

@Test func eightTapsMakeAPadProfile() throws {
    let p = profile(taps([0.05, 0.08, 0.03, 0.06, 0.05, 0.07, 0.04, 0.06]))
    #expect(p.hits == 8)
    let pad = try #require(p.profile)
    #expect(pad.noiseFloor < 0.004)
    #expect(pad.threshold > pad.noiseFloor * 3 && pad.threshold < 0.03 * 0.6)       // between the room and the softest tap
    #expect(pad.minBrightness > 0)
}

@Test func profileIsNotReadyBeforeEightTaps() {
    #expect(profile(taps([0.05, 0.05, 0.05])).profile == nil)
}

@Test func profiledDetectorHearsStrokesButNotVoices() throws {
    let pad = try #require(profile(taps([0.05, 0.08, 0.03, 0.06, 0.05, 0.07, 0.04, 0.06])).profile)
    var strokes = OnsetDetector(sampleRate: 48_000, profile: pad)
    #expect(feed(&strokes, taps([0.03, 0.05, 0.04, 0.06])).count == 4)               // soft strokes too
    var voices = OnsetDetector(sampleRate: 48_000, profile: pad)
    #expect(feed(&voices, hums(count: 4)).isEmpty)                                   // loud but dull: not a stick
}

@Test func sensitivityScalesTheProfile() {
    let pad = PadProfile(noiseFloor: 0.002, threshold: 0.01, minBrightness: 0.3)
    let more = pad.adjusted(sensitivity: 2)          // twice as sensitive
    #expect(abs(more.threshold - 0.005) < 1e-12 && abs(more.minBrightness - 0.15) < 1e-12)
    let less = pad.adjusted(sensitivity: 0.5)
    #expect(abs(less.threshold - 0.02) < 1e-12)
    // Never below the room: twice the noise floor at most sensitive.
    #expect(pad.adjusted(sensitivity: 100).threshold >= 0.004)
}

@Test func defaultDetectorFollowsSensitivityToo() {
    let d = OnsetDetector(sampleRate: 48_000, sensitivity: 2)
    #expect(abs(d.threshold - OnsetDetector(sampleRate: 48_000).threshold / 2) < 1e-12)
}
