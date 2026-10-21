import Foundation

public enum LatencyCalibrator {
    /// Median offset of detected hits against expected click times; nil with fewer than 8 matched pairs
    /// or when the spread (scaled median absolute deviation) exceeds 15 ms.
    public static func estimate(expected: [TimeInterval], detected: [TimeInterval]) -> TimeInterval? {
        var offsets: [Double] = []
        for e in expected {
            guard let nearest = detected.min(by: { abs($0 - e) < abs($1 - e) }), abs(nearest - e) <= 0.15 else { continue }
            offsets.append(nearest - e)
        }
        guard offsets.count >= 8 else { return nil }
        let m = median(offsets)
        let mad = median(offsets.map { abs($0 - m) }) * 1.4826
        return mad > 0.015 ? nil : m
    }

    static func median(_ xs: [Double]) -> Double {
        let s = xs.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }
}
