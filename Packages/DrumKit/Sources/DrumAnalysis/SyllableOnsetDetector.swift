import Foundation

/// Common shape of the stroke detector and the spoken-syllable detector, so one mic source can run either.
public protocol OnsetDetecting: Sendable {
    var suppressWindows: [ClosedRange<TimeInterval>] { get set }
    mutating func process(_ frames: [Float], startTime: TimeInterval) -> [(time: TimeInterval, strength: Double)]
    mutating func drainDiagnostics() -> [OnsetDiagnostic]
}

extension OnsetDetecting {
    /// What the detector decided about recent sharp sounds, emptied by the call (for the debug log).
    public mutating func drainDiagnostics() -> [OnsetDiagnostic] { [] }
}

extension OnsetDetector: OnsetDetecting {
    public mutating func drainDiagnostics() -> [OnsetDiagnostic] {
        defer { diagnostics.removeAll(keepingCapacity: true) }
        return diagnostics
    }
}

/// Finds the start of spoken counting syllables ("one", "and", …).
///
/// Band-limits to the voice range (150 Hz high-pass, two 2 kHz low-pass poles), measures RMS per 128-sample hop,
/// and only reports an onset once the level has stayed up for 20 ms — so short metronome clicks are ignored.
/// The reported time is the first hop that crossed the threshold.
public struct SyllableOnsetDetector: OnsetDetecting {
    public let sampleRate: Double
    public var threshold: Double
    public var minInterval: TimeInterval
    public var suppressWindows: [ClosedRange<TimeInterval>] = []

    private let hop = 128
    private let hpAlpha: Double
    private let lpAlpha: Double
    private var hpIn = 0.0, hpOut = 0.0, lp1 = 0.0, lp2 = 0.0
    private var buffer: [Double] = []
    private var bufferStart: TimeInterval?
    private var noise = 0.0
    private var candidate: TimeInterval?
    private var candidateHops = 0
    private var inSyllable = false
    private var lastOnset: TimeInterval = -.infinity

    public init(sampleRate: Double, threshold: Double = 0.005, minInterval: TimeInterval = 0.08) {
        self.sampleRate = sampleRate
        self.threshold = threshold
        self.minInterval = minInterval
        let dt = 1 / sampleRate
        let rcHP = 1 / (2 * Double.pi * 150), rcLP = 1 / (2 * Double.pi * 2000)
        hpAlpha = rcHP / (rcHP + dt)
        lpAlpha = dt / (rcLP + dt)
    }

    private var confirmHops: Int { max(1, Int((0.020 * sampleRate / Double(hop)).rounded(.up))) }

    public mutating func process(_ frames: [Float], startTime: TimeInterval) -> [(time: TimeInterval, strength: Double)] {
        if buffer.isEmpty { bufferStart = startTime }
        for x in frames {
            let h = hpAlpha * (hpOut + Double(x) - hpIn)
            hpIn = Double(x); hpOut = h
            lp1 += lpAlpha * (h - lp1)
            lp2 += lpAlpha * (lp1 - lp2)
            buffer.append(lp2)
        }
        var out: [(time: TimeInterval, strength: Double)] = []
        var used = 0
        while buffer.count - used >= hop {
            let t = (bufferStart ?? startTime) + Double(used) / sampleRate
            let slice = buffer[used..<(used + hop)]
            let rms = sqrt(slice.reduce(0) { $0 + $1 * $1 } / Double(hop))
            if let o = step(rms: rms, hopStart: t) { out.append(o) }
            used += hop
        }
        if used > 0 {
            buffer.removeFirst(used)
            bufferStart = (bufferStart ?? startTime) + Double(used) / sampleRate
        }
        return out
    }

    private mutating func step(rms: Double, hopStart: TimeInterval) -> (time: TimeInterval, strength: Double)? {
        let level = max(threshold, noise * 4)
        if rms < level * 0.3 {
            inSyllable = false
            candidate = nil
            noise = noise * 0.99 + rms * 0.01
            return nil
        }
        guard !inSyllable else { return nil }
        if candidate == nil {
            guard rms > level else { return nil }
            candidate = hopStart
            candidateHops = 1
        } else if rms > level * 0.5 {
            candidateHops += 1
        } else {
            candidate = nil
            return nil
        }
        guard candidateHops >= confirmHops, let start = candidate else { return nil }
        inSyllable = true
        candidate = nil
        guard start - lastOnset >= minInterval, !suppressWindows.contains(where: { $0.contains(start) }) else { return nil }
        lastOnset = start
        return (start, min(1, rms * 4))
    }
}

/// How evenly a spoken count lines up with where each syllable should fall.
public struct CountEvenness: Sendable, Equatable {
    /// Mean offset in ms per syllable label; beat numbers are grouped as "number".
    public let offsetsByLabel: [String: Double]
    /// Standard deviation of (spoken gap / expected gap) between consecutive matched syllables; 0 = perfectly even.
    public let gapRatioStdDev: Double
    public let matched: Int

    public init(onsets: [TimeInterval], expected: [(time: TimeInterval, label: String)]) {
        let sorted = expected.sorted { $0.time < $1.time }
        let slot = zip(sorted, sorted.dropFirst()).map { $1.time - $0.time }.min() ?? 0.5
        var matches: [(expected: TimeInterval, spoken: TimeInterval, label: String)] = []
        var used = Set<Int>()
        for e in sorted {
            let best = onsets.indices.filter { !used.contains($0) && abs(onsets[$0] - e.time) <= slot * 0.45 }
                .min { abs(onsets[$0] - e.time) < abs(onsets[$1] - e.time) }
            if let b = best {
                used.insert(b)
                matches.append((e.time, onsets[b], Int(e.label) != nil ? "number" : e.label))
            }
        }
        var groups: [String: [Double]] = [:]
        for m in matches { groups[m.label, default: []].append((m.spoken - m.expected) * 1000) }
        offsetsByLabel = groups.mapValues { $0.reduce(0, +) / Double($0.count) }
        let ratios = zip(matches, matches.dropFirst()).compactMap { a, b -> Double? in
            let exp = b.expected - a.expected
            return exp > 0 ? (b.spoken - a.spoken) / exp : nil
        }
        if ratios.count > 1 {
            let m = ratios.reduce(0, +) / Double(ratios.count)
            gapRatioStdDev = sqrt(ratios.map { pow($0 - m, 2) }.reduce(0, +) / Double(ratios.count - 1))
        } else {
            gapRatioStdDev = 0
        }
        matched = matches.count
    }
}
