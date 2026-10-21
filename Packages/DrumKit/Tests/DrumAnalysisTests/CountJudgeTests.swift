import Foundation
import Testing
@testable import DrumAnalysis

/// 1 & 2 & … at 60 BPM, 2 bars: a syllable every 0.5 s.
private let expected = (0..<16).map { (time: Double($0) * 0.5, label: $0 % 2 == 0 ? "\($0 % 8 / 2 + 1)" : "&") }

@Test func eachSyllableIsMarkedOnTimeEarlyOrLate() {
    var j = CountJudge(expected: expected)
    #expect(j.hear(0.010)?.verdict == .onTime)
    let late = j.hear(0.590)
    #expect(late?.verdict == .late)
    #expect(late?.label == "&")
    #expect(abs((late?.offsetMs ?? 0) - 90) < 0.5)
    #expect(j.hear(0.930)?.verdict == .early)
    #expect(j.hear(0.935) == nil)              // a second onset for the same syllable is not counted again
}

@Test func syllablesNobodySaidAreMissedOnceTheirWindowHasPassed() {
    var j = CountJudge(expected: expected)
    _ = j.hear(0.0)
    #expect(j.summary(until: 0.6).missed == 0)    // "&" at 0.5 may still come
    #expect(j.summary(until: 1.1).missed == 1)    // now it can't ("2" at 1.0 is still open)
}

@Test func summaryScoresAndSaysWhatToFix() {
    var j = CountJudge(expected: expected)
    // Numbers on time, every "&" 70 ms late, and the last bar's "&"s never said.
    for e in expected.prefix(12) { _ = j.hear(e.label == "&" ? e.time + 0.070 : e.time) }
    let s = j.summary(until: 10)
    #expect(s.onTime == 6)
    #expect(s.late == 6)
    #expect(s.missed == 4)
    #expect(s.score == Int(((6.0 * 100 + 6 * 50) / 16).rounded()))
    #expect(s.tips.first?.contains("&") == true)                  // the biggest problem first
    #expect(s.tips.contains { $0.contains("4") })                 // the misses are mentioned
}

@Test func aCleanCountGetsPraise() {
    var j = CountJudge(expected: expected)
    for e in expected { _ = j.hear(e.time + 0.005) }
    let s = j.summary(until: 10)
    #expect(s.score == 100)
    #expect(s.tips.count == 1)
}

@Test func speedingUpIsNoticed() {
    var j = CountJudge(expected: expected)
    // Starts on time and gets 8 ms earlier every syllable: rushing.
    for (i, e) in expected.enumerated() { _ = j.hear(e.time - Double(i) * 0.008) }
    #expect(j.summary(until: 10).tips.contains { $0.localizedCaseInsensitiveContains("nhanh dần") || $0.localizedCaseInsensitiveContains("speed") })
}
