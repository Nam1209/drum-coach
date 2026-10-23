/// Pure geometry for drawing an exercise on percussion staves: note x positions, line wrapping, beams, playhead.
public struct NotationLayout: Sendable {
    public struct Glyph: Sendable, Hashable {
        public let noteIndex: Int
        public let x: Double
        public let line: Int
        public let staffStep: Int
        public let xHead: Bool
        public let accent: Bool
        public let ghost: Bool
        public let hand: Hand?
    }

    public struct Beam: Sendable, Hashable {
        public let line: Int
        public let fromX: Double
        public let toX: Double
        /// 1 = eighths, 2 = sixteenths, 3 = thirty-seconds.
        public let level: Int
    }

    public let barWidth: Double
    public let barsPerLine: Int
    public let staffSpacing: Double
    public let lineCount: Int
    public let glyphs: [Glyph]
    public let beams: [Beam]
    private let barBeats: Rational
    private let bars: Int
    /// Fraction of the bar width kept empty at each side (0 for the scrolling line, so x is linear in beats).
    public let padding: Double

    public static let defaultPadding = 0.08

    public init(exercise: Exercise, barWidth: Double, barsPerLine: Int, staffSpacing: Double, padding: Double = defaultPadding) {
        self.barWidth = barWidth
        self.padding = padding
        self.barsPerLine = max(barsPerLine, 1)
        self.staffSpacing = staffSpacing
        barBeats = exercise.timeSignature.beatsInQuarters
        bars = max(exercise.bars, 1)
        lineCount = (bars + self.barsPerLine - 1) / self.barsPerLine

        var glyphs: [Glyph] = []
        for (i, n) in exercise.notes.enumerated() {
            let p = Self.place(n.position, barBeats: barBeats, barWidth: barWidth, barsPerLine: self.barsPerLine, padding: padding)
            glyphs.append(Glyph(noteIndex: i, x: p.x, line: p.line, staffStep: n.voice.staffStep, xHead: n.voice.usesXNotehead,
                                accent: n.articulation == .accent, ghost: n.articulation == .ghost, hand: n.hand))
        }
        self.glyphs = glyphs

        // Beam notes that share a quarter-note beat; level from the smallest gap inside the group.
        var beams: [Beam] = []
        let positions = Array(Set(exercise.notes.map(\.position))).sorted()
        let groups = Dictionary(grouping: positions) { Int($0.doubleValue + 1e-9) }
        for beat in groups.keys.sorted() {
            let ps = groups[beat]!.sorted()
            guard ps.count >= 2 else { continue }
            let gaps = zip(ps, ps.dropFirst()).map { ($1 - $0).doubleValue }
            let smallest = gaps.min() ?? 1
            let level = smallest <= 0.125 + 1e-9 ? 3 : smallest <= 0.25 + 1e-9 ? 2 : 1
            let a = Self.place(ps.first!, barBeats: barBeats, barWidth: barWidth, barsPerLine: self.barsPerLine, padding: padding)
            let b = Self.place(ps.last!, barBeats: barBeats, barWidth: barWidth, barsPerLine: self.barsPerLine, padding: padding)
            guard a.line == b.line else { continue }
            beams.append(Beam(line: a.line, fromX: a.x, toX: b.x, level: level))
        }
        self.beams = beams
    }

    /// Where the playhead is at a beat position (quarter notes from the start of the exercise; wraps per repeat).
    public func playheadX(atBeat beat: Rational) -> (line: Int, x: Double) {
        let total = (barBeats * Rational(bars, 1)).doubleValue
        var b = beat.doubleValue
        if b >= total, total > 0 { b = b.truncatingRemainder(dividingBy: total) }
        let barIndex = min(Int(b / barBeats.doubleValue), bars - 1)
        let inBar = b - Double(barIndex) * barBeats.doubleValue
        let usable = barWidth * (1 - 2 * padding)
        return (barIndex / barsPerLine,
                Double(barIndex % barsPerLine) * barWidth + barWidth * padding + inBar / barBeats.doubleValue * usable)
    }

    private static func place(_ position: Rational, barBeats: Rational, barWidth: Double, barsPerLine: Int, padding: Double) -> (line: Int, x: Double) {
        let barIndex = Int(position.doubleValue / barBeats.doubleValue + 1e-9)
        let inBar = position.doubleValue - Double(barIndex) * barBeats.doubleValue
        let usable = barWidth * (1 - 2 * padding)
        return (barIndex / barsPerLine,
                Double(barIndex % barsPerLine) * barWidth + barWidth * padding + inBar / barBeats.doubleValue * usable)
    }
}

extension Exercise {
    /// Swap right and left hands (lead with the other hand); feet are unchanged.
    public func flippedHands() -> Exercise {
        var copy = self
        copy.notes = notes.map { n in
            var m = n
            switch n.hand {
            case .right: m.hand = .left
            case .left: m.hand = .right
            default: break
            }
            return m
        }
        return copy
    }
}

extension Exercise {
    /// Bars `bars` (1-based, clamped) as their own exercise starting at beat 0 — for looping a passage.
    public func slice(bars range: ClosedRange<Int>) -> Exercise {
        let lo = max(1, min(range.lowerBound, bars)), hi = max(lo, min(range.upperBound, bars))
        let barBeats = timeSignature.beatsInQuarters
        let start = barBeats * Rational(lo - 1, 1), end = barBeats * Rational(hi, 1)
        var copy = self
        copy.notes = notes.filter { $0.position >= start && $0.position < end }.map { var n = $0; n.position = n.position - start; return n }
        copy.bars = hi - lo + 1
        copy.id = Exercise.stableID(for: "\(id)|bars|\(lo)-\(hi)")
        copy.title = title + L(" (ô \(lo)–\(hi))", " (bars \(lo)–\(hi))")
        return copy
    }
}

/// Which notation lines are on screen while playing.
public enum NotationScroll {
    /// The playing line is the top one, so the next line is always visible underneath; near the end the window stops
    /// at the last line instead of leaving empty space.
    public static func firstVisibleLine(current: Int, lineCount: Int, visible: Int) -> Int {
        max(0, min(current, lineCount - visible))
    }
}

/// The scrolling line: one staff moving left at a constant speed under a fixed playhead, the next ~8 notes in view,
/// short exercises drawn pass after pass so the line never jumps back to the start.
public enum ScrollWindow {
    /// Where the playhead sits, as a fraction of the width from the left.
    public static let headFraction = 0.2
    /// How many of the exercise's main notes fit right of the playhead.
    public static let notesAhead = 8.0

    /// The most common gap (in beats) between consecutive notes, counting the gap into the next pass; ties go to the
    /// shorter note. 1 beat when the exercise has fewer than two note times.
    public static func mainNoteLength(_ exercise: Exercise) -> Double {
        let times = Array(Set(exercise.notes.map(\.position))).sorted()
        guard times.count >= 2 else { return 1 }
        var gaps = zip(times, times.dropFirst()).map { ($1 - $0).doubleValue }
        gaps.append((exercise.lengthInBeats - times.last! + times.first!).doubleValue)
        let counts = Dictionary(grouping: gaps.map { ($0 * 960).rounded() / 960 }) { $0 }.mapValues(\.count)
        return counts.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }!.key
    }

    public static func pixelsPerBeat(width: Double, exercise: Exercise) -> Double {
        width * (1 - headFraction) / (notesAhead * mainNoteLength(exercise))
    }

    /// Passes with at least one beat between `beat - behindBeats` and `beat + aheadBeats`, never past `lastRepeat`.
    public static func repeats(beat: Double, lengthBeats: Double, behindBeats: Double, aheadBeats: Double, lastRepeat: Int) -> ClosedRange<Int>? {
        guard lengthBeats > 0 else { return nil }
        let lo = max(0, Int(((beat - behindBeats) / lengthBeats).rounded(.down)))
        let hi = min(lastRepeat, Int(((beat + aheadBeats) / lengthBeats).rounded(.down)))
        return lo <= hi ? lo...hi : nil
    }
}
