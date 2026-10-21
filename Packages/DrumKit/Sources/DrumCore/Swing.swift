/// Swing feel: the off-beat 8th ("&") is played later, at `swing` of the beat (0.5 straight … 0.75 hard shuffle).
public enum Swing {
    public static let straight = 0.5

    /// Position in beats with swing applied (only off-beat 8ths move).
    public static func position(_ p: Rational, swing: Double) -> Double {
        let whole = Double(p.num / p.den)
        let frac = p - Rational(p.num / p.den, 1)
        guard frac == Rational(1, 2) else { return p.doubleValue }
        return whole + min(0.75, max(0.5, swing))
    }
}
