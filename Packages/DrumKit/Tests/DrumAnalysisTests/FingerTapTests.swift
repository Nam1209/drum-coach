import Foundation
import Testing
@testable import DrumAnalysis

/// A fingertip on a table heard by the iPad mic ~40 cm away: a dull 5 ms thump (mostly 200–800 Hz) peaking near 0.008.
private func fingerTaps(_ times: [Double], peak: Float = 0.008, duration: Double, sr: Double = 48_000) -> [Float] {
    var out = (0..<Int(duration * sr)).map { _ in Float.random(in: -0.0005...0.0005) }
    for t0 in times {
        let start = Int(t0 * sr)
        for i in 0..<Int(0.04 * sr) where start + i < out.count {
            let t = Double(i) / sr
            out[start + i] += peak * Float(exp(-t / 0.006) * (sin(2 * .pi * 450 * t) + 0.4 * sin(2 * .pi * 900 * t)))
        }
    }
    return out
}

private func detect(_ d: inout OnsetDetector, _ s: [Float]) -> [TimeInterval] {
    var out: [TimeInterval] = []
    var i = 0
    while i < s.count {
        let end = min(i + 256, s.count)
        out += d.process(Array(s[i..<end]), startTime: Double(i) / 48_000).map(\.time)
        i = end
    }
    return out
}

@Test func fingerTapsOnATableAreHeard() {
    let times = (0..<8).map { 0.5 + Double($0) * 0.5 }
    var d = OnsetDetector.fingerTaps(sampleRate: 48_000)
    let on = detect(&d, fingerTaps(times, duration: 4.6))
    #expect(on.count == 8)
    for (o, t) in zip(on, times) { #expect(abs(o - t) <= 0.010) }
}

@Test func roomNoiseAloneIsNotATap() {
    var d = OnsetDetector.fingerTaps(sampleRate: 48_000)
    #expect(detect(&d, fingerTaps([], duration: 3)).isEmpty)
}
