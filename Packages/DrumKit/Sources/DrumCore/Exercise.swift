import Foundation

/// An exact fraction, always stored in lowest terms with a positive denominator.
/// Positions in an exercise are measured in quarter-note beats.
public struct Rational: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let num: Int
    public let den: Int

    public init(_ num: Int, _ den: Int) {
        precondition(den != 0, "Rational denominator must not be zero")
        let g = Rational.gcd(abs(num), abs(den))
        let sign = den < 0 ? -1 : 1
        self.num = sign * num / max(g, 1)
        self.den = sign * den / max(g, 1)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try c.decode(Int.self, forKey: .num), try c.decode(Int.self, forKey: .den))
    }

    public var doubleValue: Double { Double(num) / Double(den) }
    public var description: String { den == 1 ? "\(num)" : "\(num)/\(den)" }

    public static func < (a: Rational, b: Rational) -> Bool { a.num * b.den < b.num * a.den }
    public static func + (a: Rational, b: Rational) -> Rational { Rational(a.num * b.den + b.num * a.den, a.den * b.den) }
    public static func - (a: Rational, b: Rational) -> Rational { Rational(a.num * b.den - b.num * a.den, a.den * b.den) }
    public static func * (a: Rational, b: Rational) -> Rational { Rational(a.num * b.num, a.den * b.den) }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
}

public struct TimeSignature: Codable, Hashable, Sendable {
    public var beats: Int
    public var unit: Int

    public init(beats: Int, unit: Int) {
        self.beats = beats
        self.unit = unit
    }

    /// Bar length in quarter notes (7/8 → 7/2).
    public var beatsInQuarters: Rational { Rational(beats * 4, unit) }
}

public struct NoteEvent: Codable, Hashable, Sendable {
    public var position: Rational
    public var voice: Voice
    public var hand: Hand?
    public var articulation: Articulation

    public init(position: Rational, voice: Voice, hand: Hand? = nil, articulation: Articulation = .normal) {
        self.position = position
        self.voice = voice
        self.hand = hand
        self.articulation = articulation
    }
}

public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var source: String
    public var timeSignature: TimeSignature
    public var bars: Int
    public var suggestedTempo: ClosedRange<Int>
    public var notes: [NoteEvent]

    public init(id: UUID = UUID(), title: String, source: String, timeSignature: TimeSignature,
                bars: Int, suggestedTempo: ClosedRange<Int>, notes: [NoteEvent]) {
        self.id = id
        self.title = title
        self.source = source
        self.timeSignature = timeSignature
        self.bars = bars
        self.suggestedTempo = suggestedTempo
        self.notes = notes
    }

    /// Total length in quarter-note beats.
    public var lengthInBeats: Rational { timeSignature.beatsInQuarters * Rational(bars, 1) }
}
