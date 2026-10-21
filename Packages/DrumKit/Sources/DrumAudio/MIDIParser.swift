/// Extracts note-on messages from Universal MIDI Packet words (MIDI 1.0 channel voice, message type 2).
enum MIDIParser {
    static func noteOns(words: [UInt32]) -> [(note: UInt8, velocity: UInt8)] {
        words.compactMap { w in
            guard w >> 28 == 0x2 else { return nil }
            let status = UInt8((w >> 16) & 0xFF), note = UInt8((w >> 8) & 0x7F), velocity = UInt8(w & 0x7F)
            guard status & 0xF0 == 0x90, velocity > 0 else { return nil }
            return (note, velocity)
        }
    }
}
