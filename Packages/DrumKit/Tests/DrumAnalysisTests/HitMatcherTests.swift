import DrumCore
import Testing
@testable import DrumAnalysis

/// Timed notes on snare at the given seconds (hands alternate R/L).
func notes(_ times: [Double], voice: Voice = .snare) -> [TimedNote] {
    times.enumerated().map { i, t in
        TimedNote(index: i, noteIndex: i, repeatIndex: 0,
                  note: NoteEvent(position: Rational(i, 1), voice: voice, hand: i % 2 == 0 ? .right : .left), time: t)
    }
}

@Test func earlyAndLate() {
    var m = HitMatcher(expected: notes([1.0, 1.5]), beatZero: 10, window: 0.1)
    let a = m.consume(Hit(time: 10.98, voice: nil, velocity: 1))
    let b = m.consume(Hit(time: 11.53, voice: nil, velocity: 1))
    #expect(a?.first?.noteIndex == 0)
    if case .hit(let off, _) = a?.first?.result { #expect(abs(off + 0.02) < 1e-9) } else { Issue.record("not a hit") }
    if case .hit(let off, _) = b?.first?.result { #expect(abs(off - 0.03) < 1e-9) } else { Issue.record("not a hit") }
}

@Test func extraHitDoesNotStealNext() {
    var m = HitMatcher(expected: notes([1.0, 1.25]), beatZero: 0, window: 0.1)
    #expect(m.consume(Hit(time: 1.0, voice: nil, velocity: 1)) != nil)
    #expect(m.consume(Hit(time: 1.1, voice: nil, velocity: 1)) == nil)
    #expect(m.extraHits.count == 1)
    #expect(m.consume(Hit(time: 1.26, voice: nil, velocity: 1))?.first?.noteIndex == 1)
}

@Test func missedOnExpire() {
    var m = HitMatcher(expected: notes([1.0, 2.0]), beatZero: 0, window: 0.1)
    let expired = m.expire(upTo: 1.2)
    #expect(expired.count == 1)
    #expect(expired.first?.0 == 0)
    #expect(expired.first?.1 == .missed)
    #expect(m.expire(upTo: 1.3).isEmpty)
}

@Test func wrongVoiceWithMIDI() {
    var m = HitMatcher(expected: notes([1.0]), beatZero: 0, window: 0.1)
    let r = m.consume(Hit(time: 1.01, voice: .tom1, velocity: 0.8))
    #expect(r?.first?.result == .wrongVoice(offset: r!.first!.offset, played: .tom1))
}

@Test func midiPrefersMatchingVoice() {
    let hh = notes([1.0], voice: .hiHat), bd = notes([1.0], voice: .kick)
    let both = [hh[0], TimedNote(index: 1, noteIndex: 1, repeatIndex: 0, note: bd[0].note, time: 1.0)]
    var m = HitMatcher(expected: both, beatZero: 0, window: 0.1)
    #expect(m.consume(Hit(time: 1.0, voice: .kick, velocity: 1))?.map(\.noteIndex) == [1])
    #expect(m.consume(Hit(time: 1.01, voice: .hiHat, velocity: 1))?.map(\.noteIndex) == [0])
}

@Test func micHitMatchesWholeCluster() {
    let hh = notes([1.0], voice: .hiHat), bd = notes([1.0], voice: .kick)
    let both = [hh[0], TimedNote(index: 1, noteIndex: 1, repeatIndex: 0, note: bd[0].note, time: 1.0)]
    var m = HitMatcher(expected: both, beatZero: 0, window: 0.1)
    #expect(m.consume(Hit(time: 1.0, voice: nil, velocity: 1))?.count == 2)
}

@Test func hitsBeforeBeatZeroIgnored() {
    var m = HitMatcher(expected: notes([0.05]), beatZero: 100, window: 0.1)
    #expect(m.consume(Hit(time: 99.99, voice: nil, velocity: 1)) == nil)
    #expect(m.extraHits.isEmpty)
}

@Test func defaultWindowShrinksForFastNotes() {
    #expect(HitMatcher.defaultWindow(for: notes([0, 1, 2])) == 0.1)
    #expect(abs(HitMatcher.defaultWindow(for: notes([0, 0.1, 0.2])) - 0.045) < 1e-9)
}

@Test func windowNeverReachesHalfTheGap() {
    // 32nd notes at 200 BPM are 37.5 ms apart.
    let fast = notes((0..<16).map { Double($0) * 0.0375 })
    #expect(HitMatcher.window(for: fast, goodWindow: 0.045) <= 0.0375 / 2 + 1e-12)
    #expect(HitMatcher.window(for: notes([0, 0.5, 1]), goodWindow: 0.030) == 0.1)
    #expect(abs(HitMatcher.window(for: notes([0, 0.5, 1]), goodWindow: 0.08) - 0.12) < 1e-12)   // 1.5 × good, still < half gap
}

@Test func lateArrivingMicHitStillMatches() {
    var m = HitMatcher(expected: notes([1.0]), beatZero: 0, window: 0.06)
    // 400 ms later the buffered mic hit has not been delivered yet; expiry must wait for the source's report delay.
    #expect(m.expire(upTo: HitMatcher.expiryCutoff(now: 1.4, reportDelay: 0.35)).isEmpty)
    #expect(m.consume(Hit(time: 1.01, voice: nil, velocity: 1))?.first?.noteIndex == 0)
}
