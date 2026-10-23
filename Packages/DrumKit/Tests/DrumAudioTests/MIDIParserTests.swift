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

@Test func parsesPedalController() {
    // CC4 (foot controller) value 100 on channel 10: status 0xB9.
    #expect(MIDIParser.controllers(words: [0x20B9_0464]).map(\.value) == [100])
    #expect(MIDIParser.controllers(words: [0x20B9_0464]).first?.controller == 4)
    #expect(MIDIParser.controllers(words: [0x2099_2664]).isEmpty)
}

@Test func describesEveryChannelMessageForTheLog() {
    // Note on, note off (as note on velocity 0), CC4; SysEx-type words (type 3) are skipped.
    let m = MIDIParser.channelMessages(words: [0x2099_2664, 0x2099_2600, 0x20B9_0440, 0x3001_F07E])
    #expect(m.map(\.status) == [0x99, 0x99, 0xB9])
    #expect(m.map(\.data1) == [38, 38, 4])
    #expect(m.map(\.data2) == [100, 0, 64])
    #expect(m[0].summary == "Note on 38, vel 100")
    #expect(m[1].summary == "Note off 38")
    #expect(m[2].summary == "CC4 = 64")
}
