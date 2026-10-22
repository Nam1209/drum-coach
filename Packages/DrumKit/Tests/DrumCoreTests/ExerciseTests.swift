import Foundation
import Testing
@testable import DrumCore

@Test func rationalNormalizes() {
    #expect(Rational(2, 8) == Rational(1, 4))
    #expect(Rational(1, 2) < Rational(3, 4))
    #expect(Rational(-2, -4) == Rational(1, 2))
}

@Test func rationalArithmetic() {
    #expect(Rational(1, 4) + Rational(1, 4) == Rational(1, 2))
    #expect(Rational(3, 4) * Rational(2, 1) == Rational(3, 2))
    #expect(Rational(3, 2).doubleValue == 1.5)
}

@Test func midiMapping() {
    #expect(Voice.from(midiNote: 38) == .snare)
    #expect(Voice.from(midiNote: 36) == .kick)
    #expect(Voice.from(midiNote: 42) == .hiHat)
    #expect(Voice.from(midiNote: 46) == .hiHatOpen)
    #expect(Voice.from(midiNote: 51) == .ride)
    #expect(Voice.from(midiNote: 0) == nil)
}

@Test func midiOverrideWins() {
    #expect(Voice.from(midiNote: 38, overrides: [38: .tom1]) == .tom1)
    #expect(Voice.from(midiNote: 99, overrides: [99: .crash]) == .crash)
}

@Test func voiceNotation() {
    #expect(Voice.kick.staffStep == 1)
    #expect(Voice.snare.staffStep == 5)
    #expect(Voice.hiHat.usesXNotehead)
    #expect(!Voice.snare.usesXNotehead)
    #expect(Voice.hiHat.displayName == "HI-HAT")
}

@Test func exerciseRoundTripsJSON() throws {
    let ex = Exercise(
        title: "Test", source: "User",
        timeSignature: TimeSignature(beats: 4, unit: 4), bars: 1,
        suggestedTempo: 60...120,
        notes: [
            NoteEvent(position: Rational(0, 1), voice: .snare, hand: .right, articulation: .accent),
            NoteEvent(position: Rational(1, 2), voice: .snare, hand: .left, articulation: .normal),
        ])
    let data = try JSONEncoder().encode(ex)
    let back = try JSONDecoder().decode(Exercise.self, from: data)
    #expect(back == ex)
}

@Test func beatsPerBar() {
    #expect(TimeSignature(beats: 7, unit: 8).beatsInQuarters == Rational(7, 2))
    #expect(TimeSignature(beats: 4, unit: 4).beatsInQuarters == Rational(4, 1))
}

@Test func rolandEdgeNotesAreRecognised() {
    // Roland V-Drums (TD-7 included) send these for hi-hat bow/edge and the floor-tom rim by default.
    #expect(Voice.from(midiNote: 22) == .hiHat)       // closed hi-hat, edge
    #expect(Voice.from(midiNote: 26) == .hiHatOpen)   // open hi-hat, edge
    #expect(Voice.from(midiNote: 58) == .floorTom)    // floor tom rim
    #expect(Voice.from(midiNote: 22, overrides: [22: .ride]) == .ride)   // MIDI learn still wins
}
