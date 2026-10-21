import DrumCore

/// Rhythm dictation: compare the cells a student filled in with the rhythm they heard, bar by bar.
public enum DictationCheck {
    /// Grid cells (0-based, `grid` cells per quarter note) that hold a note.
    public static func cells(of e: Exercise, grid: Int) -> Set<Int> {
        Set(e.notes.map { Int(($0.position.doubleValue * Double(grid)).rounded()) })
    }

    public static func bars(answer: Set<Int>, expected: Exercise, grid: Int) -> [Bool] {
        let want = cells(of: expected, grid: grid)
        let perBar = Int((expected.timeSignature.beatsInQuarters.doubleValue * Double(grid)).rounded())
        return (0..<max(expected.bars, 1)).map { b in
            let r = (b * perBar)..<((b + 1) * perBar)
            return answer.filter { r.contains($0) } == want.filter { r.contains($0) }
        }
    }
}

/// Open/closed hi-hat from the pedal position (CC4) for kits whose stick notes don't tell them apart.
public enum HiHatPedal {
    public static func classify(_ voice: Voice, pedal: Int?, threshold: Int, higherIsClosed: Bool) -> Voice {
        guard voice == .hiHat || voice == .hiHatOpen, let pedal else { return voice }
        let closed = higherIsClosed ? pedal >= threshold : pedal < threshold
        return closed ? .hiHat : .hiHatOpen
    }
}
