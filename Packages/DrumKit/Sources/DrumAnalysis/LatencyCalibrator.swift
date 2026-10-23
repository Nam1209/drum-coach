import Foundation

public enum LatencyCalibrator {
    /// A hit counts for a click only within this distance of it.
    public static let matchWindow: TimeInterval = 0.15
    public static let minPairs = 8
    /// Largest spread (scaled median absolute deviation) accepted as a steady result.
    public static let maxSpread: TimeInterval = 0.015

    public enum Problem: Sendable, Equatable {
        /// Fewer than `minPairs` clicks had a hit within `matchWindow`.
        case tooFewMatched
        /// Enough clicks matched, but the hits were spread wider than `maxSpread`.
        case tooUneven
    }

    /// What a calibration pass measured, so the app can say why a result was refused.
    public struct Analysis: Sendable, Equatable {
        public let clicks: Int
        /// Clicks with a hit within `matchWindow`.
        public let matched: Int
        /// Hits not used for any click: taps during the count-in, double triggers, strays.
        public let unmatched: Int
        public let medianMs: Double?
        public let spreadMs: Double?
        public let problem: Problem?
        /// The latency to store, when there is no problem.
        public var estimate: TimeInterval? { problem == nil ? medianMs.map { $0 / 1000 } : nil }
    }

    public static func analyze(expected: [TimeInterval], detected: [TimeInterval]) -> Analysis {
        var offsets: [Double] = []
        for e in expected {
            guard let nearest = detected.min(by: { abs($0 - e) < abs($1 - e) }), abs(nearest - e) <= matchWindow else { continue }
            offsets.append(nearest - e)
        }
        let m = offsets.isEmpty ? nil : median(offsets)
        let spread = m.flatMap { m in offsets.count > 1 ? median(offsets.map { abs($0 - m) }) * 1.4826 : nil }
        let problem: Problem? = offsets.count < minPairs ? .tooFewMatched : (spread ?? 0) > maxSpread ? .tooUneven : nil
        return Analysis(clicks: expected.count, matched: offsets.count, unmatched: max(0, detected.count - offsets.count),
                        medianMs: m.map { $0 * 1000 }, spreadMs: spread.map { $0 * 1000 }, problem: problem)
    }

    /// Median offset of detected hits against expected click times; nil with fewer than 8 matched pairs
    /// or when the spread (scaled median absolute deviation) exceeds 15 ms.
    public static func estimate(expected: [TimeInterval], detected: [TimeInterval]) -> TimeInterval? {
        analyze(expected: expected, detected: detected).estimate
    }

    static func median(_ xs: [Double]) -> Double {
        let s = xs.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }
}

/// One calibration pass: a count-in, then `clicks` quarter notes the player hits along with.
public struct CalibrationRun: Sendable {
    public let bpm: Double
    public let countInBeats: Int
    public let clicks: Int

    public init(bpm: Double = 80, countInBeats: Int = 4, clicks: Int = 16) {
        self.bpm = bpm
        self.countInBeats = countInBeats
        self.clicks = clicks
    }

    public var duration: TimeInterval { Double(countInBeats + clicks) * 60 / bpm }

    public func expected(beatZero: TimeInterval) -> [TimeInterval] {
        (countInBeats..<(countInBeats + clicks)).map { beatZero + Double($0) * 60 / bpm }
    }
}
