import DrumCore
import Foundation

public enum NoteResult: Sendable, Hashable, Codable {
    case hit(offset: TimeInterval, velocity: Double)
    case wrongVoice(offset: TimeInterval, played: Voice)
    case missed

    public var offset: TimeInterval? {
        switch self {
        case .hit(let o, _), .wrongVoice(let o, _): o
        case .missed: nil
        }
    }
}

/// Pairs incoming hits with the notes they were meant to play.
public struct HitMatcher: Sendable {
    public struct Match: Sendable, Hashable {
        /// Timeline index of the note.
        public let noteIndex: Int
        public let result: NoteResult
        public var offset: TimeInterval { result.offset ?? 0 }
    }

    public let beatZero: TimeInterval
    public let window: TimeInterval
    private let expected: [TimedNote]
    private var pending: Set<Int>
    private var expiredUpTo = 0
    public private(set) var extraHits: [Hit] = []

    public init(expected: [TimedNote], beatZero: TimeInterval, window: TimeInterval) {
        self.expected = expected.sorted { $0.time < $1.time }
        self.beatZero = beatZero
        self.window = window
        pending = Set(expected.map(\.index))
    }

    /// min(100 ms, 45% of the smallest gap between distinct note times).
    public static func defaultWindow(for notes: [TimedNote]) -> TimeInterval {
        let times = Array(Set(notes.map(\.time))).sorted()
        let gap = zip(times, times.dropFirst()).map { $1 - $0 }.min() ?? 1
        return min(0.1, 0.45 * gap)
    }

    /// Matching window for a run: wide enough to grade orange (1.5 × the green window), but never reaching half the
    /// gap between notes — otherwise a stray hit could steal the next note.
    public static func window(for notes: [TimedNote], goodWindow: TimeInterval) -> TimeInterval {
        let times = Array(Set(notes.map(\.time))).sorted()
        let gap = zip(times, times.dropFirst()).map { $1 - $0 }.min() ?? 1
        return min(max(defaultWindow(for: notes), goodWindow * 1.5), gap / 2)
    }

    /// Notes may only be declared missed once every hit up to their window could have been delivered:
    /// microphone buffers arrive up to a few hundred ms after the sound.
    public static func expiryCutoff(now: TimeInterval, reportDelay: TimeInterval) -> TimeInterval { now - reportDelay }

    /// Matches a hit; returns the notes it played (several for a mic hit on a chord), or nil for an extra hit.
    public mutating func consume(_ hit: Hit) -> [Match]? {
        let t = hit.time - beatZero
        guard t >= 0 else { return nil }   // before this run started (count-in precedes every note)
        let candidates = expected.filter { pending.contains($0.index) && abs($0.time - t) <= window }
        guard !candidates.isEmpty else {
            extraHits.append(hit)
            return nil
        }
        if let voice = hit.voice {
            if let same = candidates.filter({ $0.note.voice == voice }).min(by: { abs($0.time - t) < abs($1.time - t) }) {
                pending.remove(same.index)
                return [Match(noteIndex: same.index, result: .hit(offset: t - same.time, velocity: hit.velocity))]
            }
            let nearest = candidates.min { abs($0.time - t) < abs($1.time - t) }!
            pending.remove(nearest.index)
            return [Match(noteIndex: nearest.index, result: .wrongVoice(offset: t - nearest.time, played: voice))]
        }
        // Microphone: one hit plays every pending note sounding at the nearest time.
        let nearestTime = candidates.min { abs($0.time - t) < abs($1.time - t) }!.time
        let cluster = candidates.filter { $0.time == nearestTime }
        for n in cluster { pending.remove(n.index) }
        return cluster.map { Match(noteIndex: $0.index, result: .hit(offset: t - $0.time, velocity: hit.velocity)) }
    }

    /// Notes whose window has passed without a hit become `.missed`.
    public mutating func expire(upTo now: TimeInterval) -> [(Int, NoteResult)] {
        let t = now - beatZero
        var out: [(Int, NoteResult)] = []
        while expiredUpTo < expected.count, expected[expiredUpTo].time + window < t {
            let n = expected[expiredUpTo]
            if pending.remove(n.index) != nil { out.append((n.index, .missed)) }
            expiredUpTo += 1
        }
        return out
    }
}
