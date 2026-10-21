import DrumCore

/// Points for every finished run. Rewards follow the Rockschool bands; only clearly sloppy playing costs a little.
/// 90%+ earns 10–20 (Distinction), 75–90% earns 3–8 (Merit), 60–75% earns 1–3 (Pass), 40–60% is the learning zone (0),
/// under 40% loses 1–5. Harder timing windows earn more; passing a level test adds 50. Runs stopped within 10 s, or that
/// the app barely heard (90%+ of notes missed — usually the mic, not the player), don't count either way. Playing an
/// exercise through to the end adds a small bonus, so finishing always beats stopping.
public enum PracticePoints {
    public static let levelTestBonus = 50
    /// Shorter runs are try-outs: no reward (so it can't be farmed) and no penalty.
    public static let minimumSeconds: Double = 10
    /// For playing to the last note (not scaled by difficulty).
    public static let completionBonus = 2

    public static func points(score: Double, goodWindowMs: Double, isLevelTest: Bool,
                              seconds: Double = .infinity, missedFraction: Double = 0, completed: Bool = false) -> Int {
        guard seconds >= minimumSeconds, missedFraction < 0.9 else { return 0 }
        return forScore(score, goodWindowMs: goodWindowMs, isLevelTest: isLevelTest) + (completed ? completionBonus : 0)
    }

    private static func forScore(_ score: Double, goodWindowMs: Double, isLevelTest: Bool) -> Int {
        let s = min(100, max(0, score))
        if s < 40 { return -Int(((40 - s) / 8).rounded(.up)) }
        if s < 60 { return 0 }
        let base = s >= 90 ? 10 + Int((s - 90).rounded())
            : s >= 75 ? 3 + Int(((s - 75) / 3).rounded())
            : 1 + Int(((s - 60) / 7.5).rounded())
        let multiplier = goodWindowMs <= 20 ? 1.5 : goodWindowMs <= 30 ? 1.0 : 0.75
        let earned = Int((Double(base) * multiplier).rounded())
        return earned + (isLevelTest && s > 90 ? levelTestBonus : 0)
    }

    /// Running total, never below zero (a bad day can't put you in debt).
    public static func total(_ runs: [Int]) -> Int {
        runs.reduce(0) { max(0, $0 + $1) }
    }
}

/// Rank from total points (separate from Rockschool grades).
public struct PracticeRank: Sendable, Equatable {
    public let level: Int
    public let title: String
    /// Points where this rank starts, and where the next one starts (nil at the top).
    public let floor: Int
    public let next: Int?

    static let floors = [0, 100, 250, 500, 900, 1500, 2500, 4000]
    static var titles: [String] {
        [L("Mới cầm dùi", "New to sticks"), L("Giữ được nhịp", "Keeping time"), L("Tay đều", "Even hands"),
         L("Vững tempo", "Steady tempo"), L("Groove ổn", "In the groove"), L("Tay lụa", "Smooth hands"),
         L("Biểu diễn", "Stage ready"), L("Bậc thầy", "Master")]
    }

    public static func `for`(points: Int) -> PracticeRank {
        let i = floors.lastIndex { points >= $0 } ?? 0
        return PracticeRank(level: i + 1, title: titles[i], floor: floors[i], next: i + 1 < floors.count ? floors[i + 1] : nil)
    }
}
