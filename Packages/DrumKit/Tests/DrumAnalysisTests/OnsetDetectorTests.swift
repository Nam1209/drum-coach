import Foundation
import Testing
@testable import DrumAnalysis

/// White noise at `noiseAmp` plus decaying 900 Hz bursts (peak `amp`, 30 ms decay) starting at `hits` seconds.
func synth(duration: Double, hits: [Double], amp: Float = 0.8, noiseAmp: Float = 0.01, sr: Double = 48_000) -> [Float] {
    var rng = SystemRandomNumberGenerator()
    var out = (0..<Int(duration * sr)).map { _ in Float.random(in: -noiseAmp...noiseAmp, using: &rng) }
    for h in hits {
        let start = Int(h * sr)
        for i in 0..<Int(0.15 * sr) where start + i < out.count {
            let t = Double(i) / sr
            out[start + i] += amp * Float(exp(-t / 0.03) * sin(2 * .pi * 900 * t))
        }
    }
    return out
}

func feed(_ d: inout OnsetDetector, _ s: [Float], chunk: Int = 256, startTime: Double = 0) -> [(time: TimeInterval, strength: Double)] {
    var out: [(time: TimeInterval, strength: Double)] = []
    var i = 0
    while i < s.count {
        let end = min(i + chunk, s.count)
        out += d.process(Array(s[i..<end]), startTime: startTime + Double(i) / 48_000)
        i = end
    }
    return out
}

@Test func detectsImpulses() {
    let hits = [0.5, 1.0, 1.5, 2.0]
    var d = OnsetDetector(sampleRate: 48_000)
    let on = feed(&d, synth(duration: 2.5, hits: hits))
    #expect(on.count == 4)
    for (o, h) in zip(on, hits) { #expect(abs(o.time - h) < 0.003) }
}

@Test func absoluteStartTimeIsRespected() {
    var d = OnsetDetector(sampleRate: 48_000)
    let on = feed(&d, synth(duration: 1, hits: [0.5]), startTime: 1000)
    #expect(on.count == 1)
    #expect(abs(on[0].time - 1000.5) < 0.003)
}

@Test func flamNotDoubleCounted() {
    var d = OnsetDetector(sampleRate: 48_000)
    #expect(feed(&d, synth(duration: 1, hits: [0.5, 0.51])).count == 1)
}

@Test func fastNotesAreSeparated() {
    var d = OnsetDetector(sampleRate: 48_000)
    #expect(feed(&d, synth(duration: 1, hits: [0.5, 0.54])).count == 2)
}

@Test func suppressWindowBlocksClick() {
    var d = OnsetDetector(sampleRate: 48_000)
    d.suppressWindows = [0.49...0.53]
    let on = feed(&d, synth(duration: 1.5, hits: [0.5, 1.0]))
    #expect(on.count == 1)
    #expect(abs(on[0].time - 1.0) < 0.003)
}

@Test func silenceGivesNothing() {
    var d = OnsetDetector(sampleRate: 48_000)
    #expect(feed(&d, synth(duration: 2, hits: [])).isEmpty)
}

@Test func louderHitIsStronger() {
    var d = OnsetDetector(sampleRate: 48_000)
    var s = synth(duration: 1.5, hits: [0.5], amp: 0.3)
    let loud = synth(duration: 1.5, hits: [1.0], amp: 0.9, noiseAmp: 0)
    for i in s.indices { s[i] += loud[i] }
    let on = feed(&d, s)
    #expect(on.count == 2)
    #expect(on[1].strength > on[0].strength * 2)
}
