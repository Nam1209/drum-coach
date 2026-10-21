import Foundation

/// What strokes on this pad in this room look like, measured from 8 taps: how loud the room is, the softest level
/// that still counts as a stroke, and how bright a stroke is (stick on rubber is bright; voices and hums are dull).
public struct PadProfile: Codable, Sendable, Equatable {
    public let noiseFloor: Double
    public let threshold: Double
    /// Minimum share of a stroke's energy above 2 kHz.
    public let minBrightness: Double

    public init(noiseFloor: Double, threshold: Double, minBrightness: Double) {
        self.noiseFloor = noiseFloor; self.threshold = threshold; self.minBrightness = minBrightness
    }
}

/// Builds a `PadProfile` from the mic while the player taps the pad 8 times: the first 0.8 s (before tapping)
/// gives the room's noise floor, then each tap's peak and brightness are recorded.
public struct PadProfiler: Sendable {
    public static let tapsNeeded = 8
    public let sampleRate: Double
    private var filters: BrightnessFilters
    private let hop = 64
    private var pending: [(low: Double, high: Double)] = []
    private var elapsed = 0.0
    private var quietPeaks: [Double] = []
    private var noiseFloor: Double?
    private var recent: [Double] = []
    private var lastHit = -Double.infinity
    private var hitPeaks: [Double] = []
    private var hitBrightness: [Double] = []

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        filters = BrightnessFilters(sampleRate: sampleRate)
    }

    /// Taps heard so far.
    public var hits: Int { hitPeaks.count }

    /// Ready once 8 taps were heard.
    public var profile: PadProfile? {
        guard let noiseFloor, hitPeaks.count >= Self.tapsNeeded else { return nil }
        let softest = hitPeaks.min() ?? 0
        let brightness = hitBrightness.sorted()[hitBrightness.count / 2]
        return PadProfile(noiseFloor: noiseFloor, threshold: max(noiseFloor * 4, softest * 0.3, 0.003),
                          minBrightness: brightness * 0.4)
    }

    public mutating func process(_ frames: [Float]) {
        for x in frames { pending.append(filters.next(Double(x))) }
        var used = 0
        while pending.count - used >= hop {
            analyze(pending[used..<(used + hop)])
            used += hop
            elapsed += Double(hop) / sampleRate
        }
        pending.removeFirst(used)
    }

    private mutating func analyze(_ h: ArraySlice<(low: Double, high: Double)>) {
        let peak = h.map { abs($0.low) }.max() ?? 0
        guard let floor = noiseFloor else {
            quietPeaks.append(peak)
            if elapsed >= 0.8 { noiseFloor = quietPeaks.sorted()[quietPeaks.count / 2] }
            return
        }
        let average = recent.isEmpty ? 0 : recent.reduce(0, +) / Double(recent.count)
        recent.append(peak); if recent.count > 8 { recent.removeFirst() }
        guard hitPeaks.count < Self.tapsNeeded, peak > floor * 6, peak > average * 2, elapsed - lastHit >= 0.08 else { return }
        lastHit = elapsed
        hitPeaks.append(peak)
        hitBrightness.append(BrightnessFilters.brightness(h))
    }
}

/// The two high-passes used to judge a sound: 150 Hz (drops rumble) and 2 kHz (keeps only the stick's crack).
struct BrightnessFilters: Sendable {
    private let lowAlpha: Double, highAlpha: Double
    private var lowIn = 0.0, lowOut = 0.0, highIn = 0.0, highOut = 0.0

    init(sampleRate: Double) {
        func alpha(_ hz: Double) -> Double { let rc = 1 / (2 * Double.pi * hz); return rc / (rc + 1 / sampleRate) }
        lowAlpha = alpha(150); highAlpha = alpha(2_000)
    }

    mutating func next(_ x: Double) -> (low: Double, high: Double) {
        let low = lowAlpha * (lowOut + x - lowIn); lowIn = x; lowOut = low
        let high = highAlpha * (highOut + x - highIn); highIn = x; highOut = high
        return (low, high)
    }

    /// Share of the energy above 2 kHz.
    static func brightness(_ h: ArraySlice<(low: Double, high: Double)>) -> Double {
        let all = h.reduce(0) { $0 + $1.low * $1.low }, high = h.reduce(0) { $0 + $1.high * $1.high }
        return all > 0 ? min(1, high / all) : 0
    }
}
