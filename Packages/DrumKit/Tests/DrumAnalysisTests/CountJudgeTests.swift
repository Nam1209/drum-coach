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
    #expect(s.tips.first?.contains("4") == true)                  // the biggest problem first: 4 missed
    #expect(s.tips.contains { $0.contains("\"&\"") && $0.contains("70") })   // then the late "&"
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

@Test func countResultsTravelInTheWeeklyDigest() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var j = CountJudge(expected: expected)
    for e in expected { _ = j.hear(e.time + 0.070) }
    let fresh = CountRecord(date: now.addingTimeInterval(-86_400), phase: "along", style: "1 & 2 &", bpm: 60, summary: j.summary(until: 10))
    let old = CountRecord(date: now.addingTimeInterval(-40 * 86_400), phase: "along", style: "1 & 2 &", bpm: 60, summary: j.summary(until: 10))
    let d = HistorySummarizer.digest([], journal: [], counting: [old, fresh], currentLevel: 1, now: now, calendar: .current)
    #expect(d.counting == [fresh])                                 // only the last 14 days
    #expect(fresh.late == 16 && fresh.score == 50 && !fresh.tips.isEmpty)
    let json = String(data: try JSONEncoder().encode(d), encoding: .utf8)!
    #expect(json.contains("\"counting\""))
    // Older digests without the field still decode.
    var dict = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
    dict["counting"] = nil
    let legacy = try JSONSerialization.data(withJSONObject: dict)
    #expect(try JSONDecoder().decode(HistoryDigest.self, from: legacy).counting == nil)
}

@Test(.vietnamese) func tappedCountGetsTappingAdvice() {
    var j = CountJudge(expected: expected, input: .tap)
    for e in expected.prefix(12) { _ = j.hear(e.label == "&" ? e.time + 0.070 : e.time) }
    let tips = j.summary(until: 10).tips
    #expect(tips.contains { $0.contains("gõ") })
    #expect(!tips.contains { $0.contains("Bạn nói") || $0.contains("Nói to") })
}
