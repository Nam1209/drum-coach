import Foundation
import DrumCore
import Testing
@testable import DrumAnalysis

private func tn(_ i: Int, pos: Rational, hand: Hand?, art: Articulation = .normal) -> TimedNote {
    TimedNote(index: i, noteIndex: i, repeatIndex: 0, note: NoteEvent(position: pos, voice: .snare, hand: hand, articulation: art), time: pos.doubleValue)
}

@Test func stats() {
    let ns = (0..<4).map { tn($0, pos: Rational($0, 2), hand: $0 % 2 == 0 ? .right : .left) }
    let results: [Int: NoteResult] = [0: .hit(offset: -0.010, velocity: 1), 1: .hit(offset: 0.010, velocity: 1),
                                      2: .hit(offset: 0.040, velocity: 1), 3: .missed]
    let s = SessionStats(results: results, notes: ns, extraHits: 0)
    #expect(s.accuracy == 0.5)
    #expect(abs(s.meanOffsetMs - 13.333) < 0.01)
    #expect(s.missed == 1)
    #expect(s.score == 62.5)          // (2 + 0.5 + 0) / 4
    #expect(abs(s.byBeatPosition["&"]! - 10) < 1e-9)
    #expect(abs(s.byHand[.right]! - 15) < 1e-9)
}

@Test func dynamics() {
    let ns = [tn(0, pos: Rational(0, 1), hand: .right, art: .accent), tn(1, pos: Rational(1, 1), hand: .left),
              tn(2, pos: Rational(2, 1), hand: .right), tn(3, pos: Rational(3, 1), hand: .left)]
    let r: [Int: NoteResult] = [0: .hit(offset: 0, velocity: 1.0), 1: .hit(offset: 0, velocity: 0.25),
                                2: .hit(offset: 0, velocity: 1.0), 3: .hit(offset: 0, velocity: 0.25)]
    let s = SessionStats(results: r, notes: ns, extraHits: 0)
    #expect(abs(s.loudnessByHandDb[.left]! - s.loudnessByHandDb[.right]! + 12.04) < 0.01)
    #expect(s.accentContrastDb != nil)
    let noAccent = SessionStats(results: r, notes: ns.map { tn($0.index, pos: $0.note.position, hand: $0.note.hand) }, extraHits: 0)
    #expect(noAccent.accentContrastDb == nil)
}

@Test func accentContrast() {
    let ns = [tn(0, pos: Rational(0, 1), hand: .right, art: .accent), tn(1, pos: Rational(1, 1), hand: .right)]
    let r: [Int: NoteResult] = [0: .hit(offset: 0, velocity: 1.0), 1: .hit(offset: 0, velocity: 0.25)]
    #expect(abs(SessionStats(results: r, notes: ns, extraHits: 0).accentContrastDb! - 12.04) < 0.01)
}

@Test func statsRoundTripJSON() throws {
    let ns = [tn(0, pos: Rational(0, 1), hand: .right)]
    let s = SessionStats(results: [0: .hit(offset: 0.01, velocity: 0.5)], notes: ns, extraHits: 1)
    let back = try JSONDecoder().decode(SessionStats.self, from: JSONEncoder().encode(s))
    #expect(back == s)
}
