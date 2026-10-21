import DrumCore
import Foundation

/// Summary of one run, stored with every practice session and sent (summarized) to the AI teacher.
public struct SessionStats: Codable, Sendable, Equatable {
    public let totalNotes: Int
    public let score: Double
    /// Share of notes graded green.
    public let accuracy: Double
    /// Negative = early, positive = late.
    public let meanOffsetMs: Double
    public let stdDevMs: Double
    public let missed: Int
    public let wrongVoice: Int
    public let extra: Int
    /// Mean offset (ms) by counting position: "1" (on the beat), "e", "&", "a", "trip", "let".
    public let byBeatPosition: [String: Double]
    public let byVoice: [Voice: Double]
    /// Mean offset (ms) by the hand the sticking asked for.
    public let byHand: [Hand: Double]
    public let velocityCV: Double?
    public let loudnessByHandDb: [Hand: Double]
    public let accentContrastDb: Double?

    public init(results: [Int: NoteResult], notes: [TimedNote], extraHits: Int, rules: ScoringRules = ScoringRules()) {
        let all = notes.map { results[$0.index] ?? .missed }
        totalNotes = notes.count
        score = rules.score(all, totalNotes: notes.count, extraHits: extraHits)
        accuracy = notes.isEmpty ? 0 : Double(all.filter { rules.grade($0) == .good }.count) / Double(notes.count)
        missed = all.filter { $0 == .missed }.count
        wrongVoice = all.filter { if case .wrongVoice = $0 { true } else { false } }.count
        extra = extraHits

        let played = notes.compactMap { n in results[n.index]?.offset.map { (n, $0 * 1000) } }
        let offsets = played.map(\.1)
        let mean = Self.mean(offsets) ?? 0
        meanOffsetMs = mean
        stdDevMs = offsets.count > 1 ? sqrt(offsets.map { pow($0 - mean, 2) }.reduce(0, +) / Double(offsets.count - 1)) : 0
        byBeatPosition = Self.groupMean(played) { Self.positionLabel($0.note.position) }
        byVoice = Self.groupMean(played) { $0.note.voice }
        byHand = Self.groupMean(played) { $0.note.hand }

        let velocities: [(TimedNote, Double)] = notes.compactMap { n in
            if case .hit(_, let v) = results[n.index], v > 0 { return (n, v) } else { return nil }
        }
        let vs = velocities.map(\.1)
        if vs.count > 1, let m = Self.mean(vs), m > 0 {
            velocityCV = sqrt(vs.map { pow($0 - m, 2) }.reduce(0, +) / Double(vs.count - 1)) / m
        } else {
            velocityCV = nil
        }
        let db = velocities.map { ($0.0, 20 * log10($0.1)) }
        loudnessByHandDb = Self.groupMean(db.filter { $0.0.note.articulation != .accent }) { $0.note.hand }
        let accents = db.filter { $0.0.note.articulation == .accent }.map(\.1)
        let normals = db.filter { $0.0.note.articulation == .normal }.map(\.1)
        if let a = Self.mean(accents), let n = Self.mean(normals) { accentContrastDb = a - n } else { accentContrastDb = nil }
    }

    static func positionLabel(_ p: Rational) -> String {
        let frac = p - Rational(Int(p.doubleValue + 1e-9), 1)
        switch frac {
        case Rational(0, 1): return "1"
        case Rational(1, 4): return "e"
        case Rational(1, 2): return "&"
        case Rational(3, 4): return "a"
        case Rational(1, 3): return "trip"
        case Rational(2, 3): return "let"
        default: return "khác"
        }
    }

    private static func mean(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count) }

    private static func groupMean<K: Hashable>(_ items: [(TimedNote, Double)], key: (TimedNote) -> K?) -> [K: Double] {
        var groups: [K: [Double]] = [:]
        for (n, v) in items { if let k = key(n) { groups[k, default: []].append(v) } }
        return groups.mapValues { $0.reduce(0, +) / Double($0.count) }
    }
}

extension SessionStats: Identifiable {
    public var id: String { "\(totalNotes)-\(score)-\(meanOffsetMs)-\(stdDevMs)" }
}
