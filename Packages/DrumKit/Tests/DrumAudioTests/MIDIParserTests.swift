import Testing
@testable import DrumAudio

@Test func parsesUMPNoteOn() {
    // MIDI 1.0 channel voice in UMP: type 2, group 0, status 0x99 (note on ch 10), note 38, velocity 100.
    let word: UInt32 = 0x2099_2664
    #expect(MIDIParser.noteOns(words: [word]).map(\.note) == [38])
    #expect(MIDIParser.noteOns(words: [word]).first?.velocity == 100)
}

@Test func ignoresNoteOffAndZeroVelocity() {
    #expect(MIDIParser.noteOns(words: [0x2089_2640, 0x2099_2600]).isEmpty)
}

@Test func ignoresOtherMessageTypes() {
    #expect(MIDIParser.noteOns(words: [0x40_99_2664, 0x10F8_0000]).isEmpty)
}

@Test func unmappedNotesAreNotHits() {
    // Note 99 is not a General MIDI drum and has no learned mapping → it must never become a scorable hit.
    #expect(MIDIHitSource.hit(note: 99, velocity: 100, time: 1, overrides: [:]) == nil)
    #expect(MIDIHitSource.hit(note: 38, velocity: 127, time: 1, overrides: [:])?.voice == .snare)
    #expect(MIDIHitSource.hit(note: 99, velocity: 64, time: 1, overrides: [99: .ride])?.voice == .ride)
}
