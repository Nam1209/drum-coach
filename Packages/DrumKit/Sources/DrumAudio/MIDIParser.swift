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

    /// Every MIDI 1.0 channel message, for the raw log in MIDI learn.
    static func channelMessages(words: [UInt32]) -> [MIDIMessage] {
        words.compactMap { w in
            guard w >> 28 == 0x2 else { return nil }
            return MIDIMessage(status: UInt8((w >> 16) & 0xFF), data1: UInt8((w >> 8) & 0x7F), data2: UInt8(w & 0x7F))
        }
    }

    /// Control changes (e.g. CC4 hi-hat pedal position).
    static func controllers(words: [UInt32]) -> [(controller: UInt8, value: UInt8)] {
        words.compactMap { w in
            guard w >> 28 == 0x2, UInt8((w >> 16) & 0xF0) == 0xB0 else { return nil }
            return (UInt8((w >> 8) & 0x7F), UInt8(w & 0x7F))
        }
    }
}

/// One raw MIDI 1.0 channel message as the kit sent it (shown in MIDI learn to diagnose stray notes).
public struct MIDIMessage: Sendable, Hashable {
    public let status: UInt8
    public let data1: UInt8
    public let data2: UInt8

    public var summary: String {
        switch status & 0xF0 {
        case 0x90 where data2 > 0: "Note on \(data1), vel \(data2)"
        case 0x90, 0x80: "Note off \(data1)"
        case 0xA0: "Aftertouch \(data1) = \(data2)"
        case 0xB0: "CC\(data1) = \(data2)"
        default: "Status \(String(status, radix: 16, uppercase: true)) \(data1) \(data2)"
        }
    }
}
