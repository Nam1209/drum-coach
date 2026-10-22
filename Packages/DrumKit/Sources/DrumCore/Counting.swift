public enum CountMode: String, Codable, CaseIterable, Sendable {
    case quarters, eighths, sixteenths, triplets, sixteenthTriplets

    /// Syllables after the beat number within one beat.
    var syllables: [String] {
        switch self {
        case .quarters: []
        case .eighths: ["&"]
        case .sixteenths: ["e", "&", "a"]
        case .triplets: ["trip", "let"]
        case .sixteenthTriplets: ["trip", "let", "&", "trip", "let"]
        }
    }
}

public enum Counting {
    /// Spoken counting labels ("1 e & a 2 …") with positions in quarter-note beats.
    public static func labels(mode: CountMode, beats: Int) -> [(position: Rational, label: String)] {
        let perBeat = mode.syllables.count + 1
        var out: [(position: Rational, label: String)] = []
        for beat in 0..<beats {
            out.append((Rational(beat, 1), "\(beat + 1)"))
            for (i, s) in mode.syllables.enumerated() {
                out.append((Rational(beat * perBeat + i + 1, perBeat), s))
            }
        }
        return out
    }
}
