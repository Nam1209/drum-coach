import DrumCore

/// Sticking exercises in the spirit of Stick Control: every R/L combination of a given length, ordered from
/// the easiest (alternating) to the hardest (most same-hand repeats). Pure combinatorics — nothing copied from the book.
public enum StickingGenerator {
    public static func singleBeat(length: Int, subdivision: Int, voice: Voice = .snare, balancedOnly: Bool) -> [Exercise] {
        combinations(length: length, balancedOnly: balancedOnly).enumerated().map { i, hands in
            make(hands: hands, subdivision: subdivision, voice: voice, title: "Sticking #\(i + 1): \(spaced(hands, every: subdivision))")
        }
    }

    public static func triplets(length: Int) -> [Exercise] {
        combinations(length: length, balancedOnly: false).enumerated().map { i, hands in
            make(hands: hands, subdivision: 3, voice: .snare, title: "Triplet #\(i + 1): \(spaced(hands, every: 3))")
        }
    }

    public static func withAccents(_ base: Exercise, accentEvery: Int, offset: Int) -> Exercise {
        var e = base
        let order = e.notes.indices.sorted { e.notes[$0].position < e.notes[$1].position }
        for (k, i) in order.enumerated() where accentEvery > 0 && k % accentEvery == offset {
            e.notes[i].articulation = .accent
        }
        e.title += " · accent"
        e.id = Exercise.stableID(for: "\(base.id)|accent|\(accentEvery)|\(offset)")
        return e
    }

    /// Right-hand notes move to `rightHand` (e.g. hi-hat), left-hand notes to `leftHand` (e.g. snare).
    public static func orchestrate(_ base: Exercise, rightHand: Voice, leftHand: Voice) -> Exercise {
        var e = base
        for i in e.notes.indices {
            switch e.notes[i].hand {
            case .right: e.notes[i].voice = rightHand
            case .left: e.notes[i].voice = leftHand
            default: break
            }
        }
        e.title += " · \(rightHand.displayName)/\(leftHand.displayName)"
        e.id = Exercise.stableID(for: "\(base.id)|orchestrate|\(rightHand.rawValue)|\(leftHand.rawValue)")
        return e
    }

    /// Reproducible snare reading line for sight-reading practice.
    public static func random(seed: UInt64, bars: Int, subdivision: Int, rests: Bool) -> Exercise {
        var rng = LibraryRNG(seed: seed)
        let cells = bars * 4 * subdivision
        var notes: [NoteEvent] = []
        var right = true
        for c in 0..<cells {
            let onBeat = c % subdivision == 0
            let playChance = onBeat ? 0.8 : 0.5
            if !rests || rng.nextUnit() < playChance {
                notes.append(NoteEvent(position: Rational(c, subdivision), voice: .snare, hand: right ? .right : .left))
                right.toggle()
            }
        }
        return Exercise(id: Exercise.stableID(for: "random|\(seed)|\(bars)|\(subdivision)|\(rests)"), title: "Đọc nhạc #\(seed)", source: "Generated", timeSignature: TimeSignature(beats: 4, unit: 4),
                        bars: bars, suggestedTempo: 60...90, notes: notes)
    }

    // MARK: -

    static func combinations(length: Int, balancedOnly: Bool) -> [[Hand]] {
        var all: [[Hand]] = []
        for mask in 0..<(1 << length) {
            let hands = (0..<length).map { (mask >> (length - 1 - $0)) & 1 == 0 ? Hand.right : .left }
            if balancedOnly, hands.filter({ $0 == .right }).count * 2 != length { continue }
            all.append(hands)
        }
        func repeats(_ h: [Hand]) -> Int { zip(h, h.dropFirst()).filter { $0 == $1 }.count }
        return all.sorted { a, b in
            let ra = repeats(a), rb = repeats(b)
            return ra != rb ? ra < rb : a.map(\.rawValue).joined() > b.map(\.rawValue).joined()   // "R" > "L"
        }
    }

    private static func make(hands: [Hand], subdivision: Int, voice: Voice, title: String) -> Exercise {
        let perBar = 4 * subdivision
        let bars = max(1, (hands.count + perBar - 1) / perBar)
        let notes = hands.enumerated().map { NoteEvent(position: Rational($0.offset, subdivision), voice: voice, hand: $0.element) }
        return Exercise(id: Exercise.stableID(for: "sticking|\(subdivision)|\(voice.rawValue)|" + hands.map(\.rawValue).joined()),
                        title: title, source: "Stick Control-style", timeSignature: TimeSignature(beats: 4, unit: 4),
                        bars: bars, suggestedTempo: 50...100, notes: notes)
    }

    private static func spaced(_ hands: [Hand], every n: Int) -> String {
        hands.enumerated().map { ($0.offset > 0 && $0.offset % max(n, 1) == 0 ? " " : "") + $0.element.rawValue }.joined()
    }
}

struct LibraryRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
