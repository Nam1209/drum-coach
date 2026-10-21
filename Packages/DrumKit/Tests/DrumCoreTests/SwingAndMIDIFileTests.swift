import Foundation
import Testing
@testable import DrumCore

@Test func swingMovesOffbeatEighths() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 2\nSN: xxxxxxxx")
    let straight = Timeline(exercise: ex, bpm: 60, repeats: 1, countInBars: 0)
    let swung = Timeline(exercise: ex, bpm: 60, repeats: 1, countInBars: 0, swing: 2.0 / 3.0)
    #expect(straight.notes[1].time == 0.5)
    #expect(abs(swung.notes[1].time - 2.0 / 3.0) < 1e-9)      // "&" pushed to the triplet position
    #expect(swung.notes[2].time == 1.0)                       // beats untouched
}

@Test func swingIsClamped() {
    #expect(Swing.position(Rational(1, 2), swing: 0.9) == 0.75)
    #expect(Swing.position(Rational(1, 2), swing: 0.2) == 0.5)
    #expect(Swing.position(Rational(1, 4), swing: 0.66) == 0.25)  // 16ths are not swung
}

/// Builds a format-0 SMF: 480 PPQ, 120 BPM, 4/4, snare (38) on every quarter, kick (36) on beat 1, channel 10.
func makeSMF() -> Data {
    func vlq(_ v: Int) -> [UInt8] {
        var v = v, out = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 { out.insert(UInt8(v & 0x7F) | 0x80, at: 0); v >>= 7 }
        return out
    }
    var track: [UInt8] = []
    track += vlq(0) + [0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]           // tempo 500000 µs = 120 BPM
    track += vlq(0) + [0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08]     // 4/4
    track += vlq(0) + [0x99, 36, 100]                                // kick on
    for q in 0..<4 {
        track += vlq(0) + [0x99, 38, 90]
        track += vlq(120) + [0x89, 38, 0]
        track += vlq(360) + [0x89, 36, 0]                            // harmless note-off filler
    }
    track += vlq(0) + [0xFF, 0x2F, 0x00]
    var data: [UInt8] = Array("MThd".utf8) + [0, 0, 0, 6, 0, 0, 0, 1, 0x01, 0xE0]
    data += Array("MTrk".utf8) + withUnsafeBytes(of: UInt32(track.count).bigEndian) { Array($0) } + track
    return Data(data)
}

@Test func midiFileBecomesExercise() throws {
    let r = try MIDIFileImporter.exercise(from: makeSMF(), title: "Song")
    #expect(r.bpm == 120)
    #expect(r.exercise.timeSignature == TimeSignature(beats: 4, unit: 4))
    #expect(r.exercise.bars == 1)
    #expect(r.exercise.notes.filter { $0.voice == .snare }.map(\.position) == [Rational(0, 1), Rational(1, 1), Rational(2, 1), Rational(3, 1)])
    #expect(r.exercise.notes.filter { $0.voice == .kick }.count == 1)
    #expect(r.unmappedNotes == 0)
}

@Test func garbageIsNotAMIDIFile() {
    #expect(throws: MIDIFileImporter.ImportError.self) { try MIDIFileImporter.exercise(from: Data("hello".utf8), title: "x") }
}

@Test func grooveScribeLink() throws {
    let ex = try ExerciseDSL.parse("title: Rock\ntime: 4/4\ngrid: 2\nHH: xxxxxxxx\nSN: --X---g-\nBD: x---x---")
    let url = GrooveScribeExport.url(for: ex, bpm: 90)!.absoluteString
    #expect(url.hasPrefix("https://www.mikeslessons.com/groove/?"))
    #expect(url.contains("TimeSig=4/4") && url.contains("Div=8") && url.contains("Tempo=90") && url.contains("Measures=1"))
    #expect(url.contains("H=%7Cxxxxxxxx%7C"))
    #expect(url.contains("S=%7C--O---g-%7C"))
    #expect(url.contains("K=%7Co---o---%7C"))
}

private func smf(_ track: [UInt8]) -> Data {
    var data: [UInt8] = Array("MThd".utf8) + [0, 0, 0, 6, 0, 0, 0, 1, 0x01, 0xE0]
    data += Array("MTrk".utf8) + withUnsafeBytes(of: UInt32(track.count).bigEndian) { Array($0) } + track
    return Data(data)
}

@Test func midiFileTooLongIsRejected() {
    // One note ~1 million beats in: must not build a million-bar exercise.
    let far: [UInt8] = [0xFF, 0xFF, 0xFF, 0x7F]                       // max VLQ delta
    let track = [0x00, 0x99, 38, 90] + far + [0x99, 38, 90] + far + [0x99, 38, 90]
    #expect(throws: MIDIFileImporter.ImportError.tooLong) { try MIDIFileImporter.exercise(from: smf(track), title: "x") }
}

@Test func truncatedMetaDoesNotCrash() {
    // Tempo meta claims 3 bytes but the file ends after 1.
    let track: [UInt8] = [0x00, 0x99, 38, 90, 0x00, 0xFF, 0x51, 0x03, 0x07]
    #expect((try? MIDIFileImporter.exercise(from: smf(track), title: "x"))?.bpm == 120)
}

@Test func zeroTempoAndBadMeterAreIgnored() {
    let track: [UInt8] = [0x00, 0xFF, 0x51, 0x03, 0, 0, 0, 0x00, 0xFF, 0x58, 0x04, 0, 200, 24, 8, 0x00, 0x99, 38, 90]
    let r = try? MIDIFileImporter.exercise(from: smf(track), title: "x")
    #expect(r?.bpm == 120)
    #expect(r?.exercise.timeSignature == TimeSignature(beats: 4, unit: 4))
}
