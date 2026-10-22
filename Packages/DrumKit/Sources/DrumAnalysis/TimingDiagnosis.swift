import Foundation

/// Tells apart the kinds of timing error, following the rule "consistent error is settings, growing error is you":
/// a constant offset points at latency calibration; an offset that grows through the run means rushing or dragging.
public struct TimingDiagnosis: Sendable, Equatable {
    public enum Kind: String, Sendable { case steady, constantOffset, rushing, dragging, uneven, notEnoughData }

    public let kind: Kind
    public let meanMs: Double
    /// Change of the offset per minute of playing (positive = getting later).
    public let driftMsPerMinute: Double
    /// Spread around the trend line.
    public let spreadMs: Double

    /// `samples`: time of each played note (seconds) and its offset (ms).
    public init(samples: [(time: Double, offsetMs: Double)]) {
        let n = Double(samples.count)
        guard samples.count >= 8 else {
            kind = .notEnoughData; meanMs = 0; driftMsPerMinute = 0; spreadMs = 0
            return
        }
        let mt = samples.map(\.time).reduce(0, +) / n, mo = samples.map(\.offsetMs).reduce(0, +) / n
        let sxx = samples.reduce(0) { $0 + pow($1.time - mt, 2) }
        let slope = sxx > 0 ? samples.reduce(0) { $0 + ($1.time - mt) * ($1.offsetMs - mo) } / sxx : 0   // ms per second
        let residuals = samples.map { $0.offsetMs - (mo + slope * ($0.time - mt)) }
        let spread = sqrt(residuals.map { $0 * $0 }.reduce(0, +) / max(n - 2, 1))
        let span = (samples.map(\.time).max() ?? 0) - (samples.map(\.time).min() ?? 0)
        meanMs = mo
        driftMsPerMinute = slope * 60
        spreadMs = spread
        if abs(slope * span) >= 25, abs(slope * 60) >= 30 { kind = slope > 0 ? .dragging : .rushing }
        else if spread > 15 { kind = .uneven }
        else if abs(mo) >= 15 { kind = .constantOffset }
        else { kind = .steady }
    }
}
