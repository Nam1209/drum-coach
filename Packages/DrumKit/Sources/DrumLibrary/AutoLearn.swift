import DrumCore

/// Step-by-step plan for learning a longer exercise: each short segment, then overlapping chains of segments,
/// then the whole piece with the click and finally without it.
public struct AutoLearnPlan: Sendable {
    public struct Step: Sendable, Hashable {
        /// 1-based bar range.
        public let bars: ClosedRange<Int>
        public let withClick: Bool
        public var title: String {
            withClick ? L("Ô \(bars.lowerBound)–\(bars.upperBound)", "Bars \(bars.lowerBound)–\(bars.upperBound)")
                      : L("Cả bài, không click", "Whole piece, no click")
        }
    }

    public let steps: [Step]

    public init(exercise: Exercise, barsPerSegment: Int = 2) {
        let total = max(exercise.bars, 1), size = max(barsPerSegment, 1)
        let segments = stride(from: 1, through: total, by: size).map { $0...min($0 + size - 1, total) }
        var steps: [Step] = []
        if segments.count > 1 {
            steps += segments.map { Step(bars: $0, withClick: true) }
            var chain = 2
            while chain < segments.count {
                let strideBy = chain == 2 ? 1 : chain / 2
                var start = 0
                while start + chain <= segments.count {
                    steps.append(Step(bars: segments[start].lowerBound...segments[start + chain - 1].upperBound, withClick: true))
                    start += strideBy
                }
                chain *= 2
            }
        }
        steps.append(Step(bars: 1...total, withClick: true))
        steps.append(Step(bars: 1...total, withClick: false))
        self.steps = steps
    }
}

/// Tempo for learning: start at half speed, +5 BPM after each pass (> 90%), −10 after three fails in a row,
/// never below 30% of the target.
public struct AdaptiveTempo: Sendable {
    public let target: Int
    public private(set) var bpm: Int
    private var fails = 0

    public init(target: Int) {
        self.target = target
        bpm = Int((Double(target) * 0.5).rounded())
    }

    public var atTarget: Bool { bpm >= target }

    @discardableResult
    public mutating func record(score: Double) -> Int {
        if score > 90 {
            fails = 0
            bpm = min(bpm + 5, target)
        } else {
            fails += 1
            if fails >= 3 {
                bpm = max(bpm - 10, Int((Double(target) * 0.3).rounded()))
                fails = 0
            }
        }
        return bpm
    }
}

extension StickingGenerator {
    /// The groove with one extra kick on each free grid position (not already kick or snare) — GrooveScribe-style permutations.
    public static func kickPermutations(_ base: Exercise) -> [Exercise] { permutations(base, adding: .kick, articulation: .normal, name: L("Hoán vị kick", "Kick permutation")) }

    /// The groove with one extra snare (ghost note) on each free grid position.
    public static func snarePermutations(_ base: Exercise) -> [Exercise] { permutations(base, adding: .snare, articulation: .ghost, name: L("Hoán vị snare", "Snare permutation")) }

    private static func permutations(_ base: Exercise, adding voice: Voice, articulation: Articulation, name: String) -> [Exercise] {
        let positions = Array(Set(base.notes.map(\.position))).sorted()
        let gap = zip(positions, positions.dropFirst()).map { $1 - $0 }.min() ?? Rational(1, 2)
        let step = gap < Rational(1, 2) ? gap : Rational(1, 2)
        let taken = Set(base.notes.filter { $0.voice == .kick || $0.voice == .snare }.map(\.position))
        var out: [Exercise] = []
        var p = Rational(0, 1)
        while p < base.lengthInBeats {
            if !taken.contains(p) {
                var e = base
                e.notes.append(NoteEvent(position: p, voice: voice, hand: voice == .kick ? .foot : nil, articulation: articulation))
                e.notes.sort { $0.position < $1.position }
                e.id = Exercise.stableID(for: "\(base.id)|perm|\(voice.rawValue)|\(p)")
                e.title = "\(name) #\(out.count + 1) · \(base.title)"
                out.append(e)
            }
            p = p + step
        }
        return out
    }
}
