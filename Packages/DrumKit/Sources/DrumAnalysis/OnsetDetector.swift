import Foundation

/// Finds stick strokes in a mono microphone signal.
///
/// The signal is high-passed (drops rumble and room noise), cut into 64-sample hops, and a hop starts an onset when
/// its peak clears an adaptive threshold and is at least twice the average of the previous ~10 ms. The onset time is
/// the first sample in that hop above the threshold.
public struct OnsetDetector: Sendable {
    public let sampleRate: Double
    public var threshold: Double
    public var minInterval: TimeInterval
    /// Onsets inside these host-time ranges are dropped (metronome bleeding into the mic).
    public var suppressWindows: [ClosedRange<TimeInterval>] = []

    private let hop = 64
    private let hpAlpha: Double
    private var hpPrevIn = 0.0, hpPrevOut = 0.0
    private var pending: [Double] = []
    private var pendingStart: TimeInterval?
    private var recentPeaks: [Double] = []
    private var noiseFloor = 0.0
    private var lastOnset: TimeInterval = -.infinity

    public init(sampleRate: Double, threshold: Double = 0.15, minInterval: TimeInterval = 0.025) {
        self.sampleRate = sampleRate
        self.threshold = threshold
        self.minInterval = minInterval
        let rc = 1 / (2 * Double.pi * 150)
        hpAlpha = rc / (rc + 1 / sampleRate)
    }

    public mutating func process(_ frames: [Float], startTime: TimeInterval) -> [(time: TimeInterval, strength: Double)] {
        if pending.isEmpty { pendingStart = startTime }
        for x in frames {
            let y = hpAlpha * (hpPrevOut + Double(x) - hpPrevIn)
            hpPrevIn = Double(x)
            hpPrevOut = y
            pending.append(y)
        }
        var out: [(time: TimeInterval, strength: Double)] = []
        var consumed = 0
        while pending.count - consumed >= hop {
            let hopStart = (pendingStart ?? startTime) + Double(consumed) / sampleRate
            if let onset = analyze(pending[consumed..<(consumed + hop)], hopStart: hopStart) { out.append(onset) }
            consumed += hop
        }
        if consumed > 0 {
            pending.removeFirst(consumed)
            pendingStart = (pendingStart ?? startTime) + Double(consumed) / sampleRate
        }
        return out
    }

    private mutating func analyze(_ hopSamples: ArraySlice<Double>, hopStart: TimeInterval) -> (time: TimeInterval, strength: Double)? {
        let peak = hopSamples.map(abs).max() ?? 0
        let recent = recentPeaks.isEmpty ? 0 : recentPeaks.reduce(0, +) / Double(recentPeaks.count)
        recentPeaks.append(peak)
        if recentPeaks.count > 8 { recentPeaks.removeFirst() }

        let level = max(threshold, noiseFloor * 4)
        var result: (time: TimeInterval, strength: Double)?
        if peak > level, peak > recent * 2 {
            let offset = hopSamples.firstIndex { abs($0) > level }.map { $0 - hopSamples.startIndex } ?? 0
            let t = hopStart + Double(offset) / sampleRate
            if t - lastOnset >= minInterval {
                lastOnset = t
                if !suppressWindows.contains(where: { $0.contains(t) }) { result = (t, min(1, peak)) }
            }
        } else if peak < level {
            noiseFloor = noiseFloor * 0.995 + peak * 0.005
        }
        return result
    }
}
