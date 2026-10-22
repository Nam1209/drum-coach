import Foundation

/// Reads a Standard MIDI File's drum part (channel 10, or every note when the file has none there) into an exercise.
public enum MIDIFileImporter {
    public enum ImportError: Error, Equatable { case notMIDI, noNotes, tooLong, unsupported(String) }

    /// Longest import (a whole song at 4/4 is ~100–200 bars).
    public static let maxBars = 256

    public struct Result: Sendable {
        public let exercise: Exercise
        public let bpm: Int
        /// Notes that are not General MIDI drums (left out).
        public let unmappedNotes: Int
    }

    public static func exercise(from data: Data, title: String, overrides: [UInt8: Voice] = [:]) throws(ImportError) -> Result {
        let b = [UInt8](data)
        guard b.count >= 14, Array(b[0..<4]) == Array("MThd".utf8) else { throw .notMIDI }
        // Variable-length quantity, never reading past `end`.
        func vlq(_ i: inout Int, _ end: Int) -> Int {
            var v = 0
            // At most 4 bytes (≤ 0x0FFFFFFF) as the SMF spec says, so the value is never negative.
            for _ in 0..<4 where i < end {
                let byte = b[i]; i += 1
                v = v << 7 | Int(byte & 0x7F)
                if byte & 0x80 == 0 { return v }
            }
            // Longer than 4 bytes: skip the rest of the malformed number.
            while i < end, b[i - 1] & 0x80 != 0 { i += 1 }
            return v
        }
        func u16(_ i: Int) -> Int { Int(b[i]) << 8 | Int(b[i + 1]) }
        func u32(_ i: Int) -> Int { Int(b[i]) << 24 | Int(b[i + 1]) << 16 | Int(b[i + 2]) << 8 | Int(b[i + 3]) }
        let headerLength = u32(4)
        let division = u16(12)
        guard division & 0x8000 == 0, division > 0 else { throw .unsupported("SMPTE timing") }
        var tempo = 500_000, timeSig = TimeSignature(beats: 4, unit: 4)
        var gotTempo = false, gotSig = false
        var notes: [(tick: Int, note: UInt8, velocity: UInt8, channel: UInt8)] = []

        var p = 8 + headerLength
        while p >= 0, p + 8 <= b.count {
            let chunkLength = u32(p + 4)
            let isTrack = Array(b[p..<p + 4]) == Array("MTrk".utf8)
            let end = min(p + 8 + chunkLength, b.count)
            var i = p + 8, tick = 0, running: UInt8 = 0
            while isTrack && i < end {
                tick += vlq(&i, end)
                guard tick <= Int(Int32.max) else { throw .tooLong }
                guard i < end else { break }
                var status = b[i]
                if status & 0x80 != 0 { i += 1; if status < 0xF0 { running = status } } else { status = running }
                switch status {
                case 0xFF:
                    guard i < end else { break }
                    let type = b[i]; i += 1
                    let len = vlq(&i, end)
                    guard len <= end - i else { i = end; break }
                    if type == 0x51, len == 3, !gotTempo {
                        let t = Int(b[i]) << 16 | Int(b[i + 1]) << 8 | Int(b[i + 2])
                        if t >= 100_000 { tempo = t; gotTempo = true }        // ≤ 600 BPM
                    }
                    if type == 0x58, len >= 2, !gotSig, (1...32).contains(b[i]), b[i + 1] <= 5 {
                        timeSig = TimeSignature(beats: Int(b[i]), unit: 1 << Int(b[i + 1])); gotSig = true
                    }
                    i += len
                case 0xF0, 0xF7:
                    let len = vlq(&i, end)
                    i += min(len, end - i)
                default:
                    let kind = status & 0xF0, ch = status & 0x0F
                    let size = (kind == 0xC0 || kind == 0xD0) ? 1 : 2
                    guard i + size <= end else { i = end; break }
                    if kind == 0x90, b[i + 1] > 0 {
                        // Past the longest import: stop before building a huge exercise.
                        guard Double(tick) / Double(division) <= Double(maxBars * 8) else { throw .tooLong }
                        notes.append((tick, b[i], b[i + 1], ch))
                    }
                    i += size
                }
            }
            p = end
        }
        let drums = notes.contains { $0.channel == 9 } ? notes.filter { $0.channel == 9 } : notes
        guard !drums.isEmpty else { throw .noNotes }

        var events: [NoteEvent] = []
        var unmapped = 0
        for n in drums {
            guard let voice = Voice.from(midiNote: n.note, overrides: overrides) else { unmapped += 1; continue }
            // Quantize to 1/12 of a beat (covers 16ths and triplets).
            let pos = Rational(Int((Double(n.tick) * 12 / Double(division)).rounded()), 12)
            let accent = n.velocity >= 115, ghost = n.velocity <= 45
            events.append(NoteEvent(position: pos, voice: voice, articulation: accent ? .accent : ghost ? .ghost : .normal))
        }
        guard !events.isEmpty else { throw .noNotes }
        events.sort { $0.position < $1.position }
        let barBeats = timeSig.beatsInQuarters.doubleValue
        let bars = max(1, Int((events.last!.position.doubleValue / barBeats).rounded(.down)) + 1)
        guard bars <= maxBars else { throw .tooLong }
        let bpm = Int((60_000_000 / Double(tempo)).rounded())
        let ex = Exercise(id: Exercise.stableID(for: "midi|\(title)|\(events.count)|\(bars)"), title: title, source: "MIDI",
                          timeSignature: timeSig, bars: bars, suggestedTempo: max(30, bpm / 2)...max(30, bpm), notes: events)
        return Result(exercise: ex, bpm: bpm, unmappedNotes: unmapped)
    }
}

/// Opens an exercise in GrooveScribe (mikeslessons.com) to view, print or share it.
public enum GrooveScribeExport {
    public static func url(for e: Exercise, bpm: Int) -> URL? {
        let positions = Array(Set(e.notes.map(\.position))).sorted()
        let gap = zip(positions, positions.dropFirst()).map { ($1 - $0).doubleValue }.min() ?? 0.5
        let div: Int = gap >= 0.5 - 1e-9 ? 8 : abs(gap - 1.0 / 3) < 1e-6 ? 12 : abs(gap - 1.0 / 6) < 1e-6 ? 24 : 16
        let cellsPerQuarter = div / 4 == 0 ? 2 : (div == 12 ? 3 : div == 24 ? 6 : div / 4)
        let perBar = Int((e.timeSignature.beatsInQuarters.doubleValue * Double(cellsPerQuarter)).rounded())
        let total = perBar * max(e.bars, 1)
        func line(_ symbol: (NoteEvent) -> Character?) -> String {
            var cells = Array(repeating: Character("-"), count: total)
            for n in e.notes {
                let i = Int((n.position.doubleValue * Double(cellsPerQuarter)).rounded())
                if i >= 0, i < total, let c = symbol(n) { cells[i] = c }
            }
            return "|" + stride(from: 0, to: total, by: perBar).map { String(cells[$0..<min($0 + perBar, total)]) }.joined(separator: "|") + "|"
        }
        let hh = line { n in
            switch n.voice { case .hiHat: "x"; case .hiHatOpen: "o"; case .ride: "r"; case .crash: "c"; default: nil }
        }
        let sn = line { n in
            guard n.voice == .snare || n.voice == .sideStick else { return nil }
            if n.voice == .sideStick { return "x" }
            switch n.articulation { case .accent: return "O"; case .ghost: return "g"; case .flam: return "f"; case .drag: return "d"; case .buzz: return "b"; case .normal: return "o" }
        }
        let kick = line { n in n.voice == .kick ? "o" : n.voice == .hiHatPedal ? "x" : nil }
        let t1 = line { $0.voice == .tom1 ? "o" : nil }, t2 = line { $0.voice == .tom2 ? "o" : nil }, t4 = line { $0.voice == .floorTom ? "o" : nil }
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-/"))) ?? s }
        var q = "TimeSig=\(e.timeSignature.beats)/\(e.timeSignature.unit)&Div=\(div)&Title=\(enc(e.title))&Tempo=\(bpm)&Measures=\(max(e.bars, 1))"
        q += "&H=\(enc(hh))&S=\(enc(sn))&K=\(enc(kick))"
        if e.notes.contains(where: { $0.voice == .tom1 }) { q += "&T1=\(enc(t1))" }
        if e.notes.contains(where: { $0.voice == .tom2 }) { q += "&T2=\(enc(t2))" }
        if e.notes.contains(where: { $0.voice == .floorTom }) { q += "&T4=\(enc(t4))" }
        return URL(string: "https://www.mikeslessons.com/groove/?" + q)
    }
}
