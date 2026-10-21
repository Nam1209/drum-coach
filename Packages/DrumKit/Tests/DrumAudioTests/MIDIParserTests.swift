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
