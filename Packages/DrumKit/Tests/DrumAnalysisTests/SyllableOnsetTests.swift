import Foundation
import Testing
@testable import DrumAnalysis

/// "Syllables": 300 Hz tone with a 120 ms envelope (10 ms attack) at the given times, plus light noise.
private func speech(_ times: [Double], duration: Double, sr: Double = 48_000, peak: Double = 0.4, noise: Float = 0.005) -> [Float] {
    var out = (0..<Int(duration * sr)).map { _ in Float.random(in: -noise...noise) }
    for t0 in times {
        let start = Int(t0 * sr)
        for i in 0..<Int(0.12 * sr) where start + i < out.count {
            let t = Double(i) / sr
            let env = min(1, t / 0.01) * (t > 0.09 ? max(0, (0.12 - t) / 0.03) : 1)
            out[start + i] += Float(peak * env * sin(2 * .pi * 300 * t))
        }
    }
    return out
}

private func run(_ d: inout SyllableOnsetDetector, _ s: [Float]) -> [TimeInterval] {
    var out: [TimeInterval] = []
    var i = 0
    while i < s.count {
        let end = min(i + 256, s.count)
        out += d.process(Array(s[i..<end]), startTime: Double(i) / 48_000).map(\.time)
        i = end
    }
    return out
}

@Test func detectsEvenSyllables() {
    let times = (0..<8).map { 0.2 + Double($0) * 0.333 }
    var d = SyllableOnsetDetector(sampleRate: 48_000)
    let on = run(&d, speech(times, duration: 3.2))
    #expect(on.count == 8)
    for (o, t) in zip(on, times) { #expect(abs(o - t) <= 0.010) }
}

/// Counting measured on the iPad peaked at only 0.03–0.04 on the mic; the detector must still hear it.
@Test func detectsQuietSpeechLikeTheIPadMic() {
    let times = (0..<8).map { 0.6 + Double($0) * 0.333 }
    var d = SyllableOnsetDetector(sampleRate: 48_000)
    let on = run(&d, speech(times, duration: 3.6, peak: 0.03, noise: 0.0005))
    #expect(on.count == 8)
}

@Test func shortHighClickIsIgnored() {
    var s = speech([], duration: 1)
    for i in 0..<240 { s[24_000 + i] += Float(0.8 * sin(2 * .pi * 4000 * Double(i) / 48_000)) }
    var d = SyllableOnsetDetector(sampleRate: 48_000)
    #expect(run(&d, s).isEmpty)
}

@Test func evennessFindsLateAnd() {
    // 1 & 2 & … at 60 BPM: numbers on the beat, "&" spoken 40 ms late.
    let expected = (0..<8).map { (time: Double($0) * 0.5, label: $0 % 2 == 0 ? "\($0 / 2 + 1)" : "&") }
    let onsets = expected.map { $0.label == "&" ? $0.time + 0.040 : $0.time }
    let e = CountEvenness(onsets: onsets, expected: expected)
    #expect(abs(e.offsetsByLabel["&"]! - 40) < 0.5)
    #expect(abs(e.offsetsByLabel["number"]!) < 0.5)
    #expect(e.gapRatioStdDev > 0.05)
    #expect(e.matched == 8)
}

@Test func evennessOfPerfectCount() {
    let expected = (0..<8).map { (time: Double($0) * 0.5, label: $0 % 2 == 0 ? "1" : "&") }
    let e = CountEvenness(onsets: expected.map(\.time), expected: expected)
    #expect(e.gapRatioStdDev < 1e-9)
}
