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
    /// Minimum share of an onset's energy above 2 kHz (0 = any sound). Set from a `PadProfile` so only stick-like
    /// cracks count, not voices or hums.
    public var minBrightness: Double = 0
    /// Onsets inside these host-time ranges are dropped (metronome bleeding into the mic).
    public var suppressWindows: [ClosedRange<TimeInterval>] = []

    private let hop = 64
    private var filters: BrightnessFilters
    private var pending: [(low: Double, high: Double)] = []
    private var pendingStart: TimeInterval?
    private var recentPeaks: [Double] = []
    private var noiseFloor = 0.0
    private var lastOnset: TimeInterval = -.infinity

    /// `threshold` is the lowest peak (after the high-pass) that can count as a stroke. iPad mics in measurement mode
    /// have no automatic gain, so a rubber pad often peaks at only 2–5% of full scale: the default is low, and the
    /// effective level rises with the room's noise floor so background noise is still ignored.
    public init(sampleRate: Double, threshold: Double = 0.012, minInterval: TimeInterval = 0.025) {
        self.sampleRate = sampleRate
        self.threshold = threshold
        self.minInterval = minInterval
        filters = BrightnessFilters(sampleRate: sampleRate)
    }

    /// The default detector with the player's sensitivity setting (2 = twice as sensitive).
    public init(sampleRate: Double, sensitivity: Double, minInterval: TimeInterval = 0.025) {
        self.init(sampleRate: sampleRate, threshold: 0.012 / max(sensitivity, 0.1), minInterval: minInterval)
    }

    /// Tuned to the pad and room measured by `PadProfiler`.
    /// Fingertips tapped on a table: far quieter than a stick on a pad, and never faster than 16ths at counting tempos.
    public static func fingerTaps(sampleRate: Double, sensitivity: Double = 1) -> OnsetDetector {
        OnsetDetector(sampleRate: sampleRate, threshold: 0.004 / max(sensitivity, 0.1), minInterval: 0.08)
    }

    public init(sampleRate: Double, profile: PadProfile, minInterval: TimeInterval = 0.025) {
        self.init(sampleRate: sampleRate, threshold: profile.threshold, minInterval: minInterval)
        minBrightness = profile.minBrightness
    }

    public mutating func process(_ frames: [Float], startTime: TimeInterval) -> [(time: TimeInterval, strength: Double)] {
        if pending.isEmpty { pendingStart = startTime }
        for x in frames { pending.append(filters.next(Double(x))) }
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

    private mutating func analyze(_ hopFilters: ArraySlice<(low: Double, high: Double)>, hopStart: TimeInterval) -> (time: TimeInterval, strength: Double)? {
        let hopSamples = hopFilters.map(\.low)[...]
        let peak = hopSamples.map(abs).max() ?? 0
        let recent = recentPeaks.isEmpty ? 0 : recentPeaks.reduce(0, +) / Double(recentPeaks.count)
        recentPeaks.append(peak)
        if recentPeaks.count > 8 { recentPeaks.removeFirst() }

        let level = max(threshold, noiseFloor * 5)
        var result: (time: TimeInterval, strength: Double)?
        if peak > level, peak > recent * 2, minBrightness == 0 || BrightnessFilters.brightness(hopFilters) >= minBrightness {
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
