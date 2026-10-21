import Foundation

public enum Grade: Sendable, Hashable {
    /// green
    case good
    /// orange, mark drawn before the note
    case early
    /// orange, mark drawn after the note
    case late
    /// red
    case missed
}

/// Green = within `goodWindow`; orange = early/late but matched; red = missed.
/// Score: green 1, orange 0.5, red 0, each extra hit −0.5; percentage of all notes, clamped to 0…100.
public struct ScoringRules: Codable, Sendable, Equatable {
    public var goodWindow: TimeInterval
    public var extraHitPenalty: Double

    public init(goodWindow: TimeInterval = 0.030, extraHitPenalty: Double = 0.5) {
        self.goodWindow = goodWindow
        self.extraHitPenalty = extraHitPenalty
    }

    public static let easy = ScoringRules(goodWindow: 0.045)
    public static let hard = ScoringRules(goodWindow: 0.020)

    public func grade(_ r: NoteResult) -> Grade {
        guard let o = r.offset else { return .missed }
        if case .hit = r, abs(o) <= goodWindow { return .good }
        return o < 0 ? .early : .late
    }

    public func score(_ results: [NoteResult], totalNotes: Int, extraHits: Int) -> Double {
        guard totalNotes > 0 else { return 0 }
        let points = results.reduce(0.0) { sum, r in
            switch grade(r) {
            case .good: sum + 1
            case .early, .late: sum + 0.5
            case .missed: sum
            }
        }
        return max(0, min(100, (points - extraHitPenalty * Double(extraHits)) / Double(totalNotes) * 100))
    }
}
