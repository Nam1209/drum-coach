import DrumCore

/// Points for every finished run. Rewards follow the Rockschool bands; only clearly sloppy playing costs a little.
/// 90%+ earns 10–20 (Distinction), 75–90% earns 3–8 (Merit), 60–75% earns 1–3 (Pass), 40–60% is the learning zone (0),
/// under 40% loses 1–5. Harder timing windows earn more; passing a level test adds 50. Runs stopped within 10 s, or that
/// the app barely heard (90%+ of notes missed — usually the mic, not the player), don't count either way. Playing an
/// exercise through to the end adds a bonus that grows with its length, so finishing always beats stopping.
public enum PracticePoints {
    public static let levelTestBonus = 50
    /// Shorter runs are try-outs: no reward (so it can't be farmed) and no penalty.
    public static let minimumSeconds: Double = 10
    /// For playing to the last note: +1 per 30 s, at least 2 and at most 10, so sticking with a long exercise pays more
    /// (not scaled by difficulty).
    /// Finishing only earns the bonus at Pass (60%) or better: lasting through a run is rewarded only when it was decent.
    public static let completionMinScore: Double = 60

    public static func completionBonus(seconds: Double) -> Int {
        min(10, max(2, Int((seconds / 30).rounded())))
    }

    public static func points(score: Double, goodWindowMs: Double, isLevelTest: Bool,
                              seconds: Double = .infinity, missedFraction: Double = 0, completed: Bool = false) -> Int {
        guard seconds >= minimumSeconds, missedFraction < 0.9 else { return 0 }
        return forScore(score, goodWindowMs: goodWindowMs, isLevelTest: isLevelTest) + (completed && score >= completionMinScore ? completionBonus(seconds: seconds) : 0)
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

/// The player's level, kept in step with Rockschool: Level N means the app's Grade N tests are passed AND enough
/// practice points have been earned, like an exam that also expects the practice hours behind it.
///
/// Points needed per grade: the forecast's typical 5.5 months per grade (Grades 1–5) at 30 min a day, at about
/// 2 points per minute of normal practice (mostly 70–85%, exercises finished): 5.5 × 30 × 30 × 2 ≈ 10,000.
/// Grades 6–8 take 1.5× as long (as in ProgressForecast), so 15,000 each.
public struct PracticeRank: Sendable, Equatable {
    /// 0 (no grade yet) … 8.
    public let level: Int
    public let title: String
    /// Points where this level starts, and where the next one starts (nil at the top).
    public let floor: Int
    public let next: Int?
    /// Grade the points alone would reach, and the grade whose tests are passed.
    public let pointsGrade: Int
    public let testsGrade: Int

    /// Enough practice for a higher grade than the tests passed: take the next test.
    public var needsTest: Bool { pointsGrade > testsGrade }
    /// Tests passed ahead of the practice: keep practising to make the level count.
    public var needsPractice: Bool { testsGrade > pointsGrade }

    public static let floors = [0, 10_000, 20_000, 30_000, 40_000, 50_000, 65_000, 80_000, 95_000]
    static var titles: [String] {
        [L("Mới cầm dùi", "New to sticks"), L("Giữ được nhịp", "Keeping time"), L("Tay đều", "Even hands"),
         L("Vững tempo", "Steady tempo"), L("Groove ổn", "In the groove"), L("Tay lụa", "Smooth hands"),
         L("Biểu diễn", "Stage ready"), L("Nghệ sĩ", "Artist"), L("Bậc thầy", "Master")]
    }

    public static func `for`(points: Int, grade: Int) -> PracticeRank {
        let byPoints = floors.lastIndex { points >= $0 } ?? 0
        let byTests = min(max(grade, 0), floors.count - 1)
        let level = min(byPoints, byTests)
        let name = level == 0 ? titles[0] : "Grade \(level) · \(titles[level])"
        return PracticeRank(level: level, title: name, floor: floors[level],
                            next: level + 1 < floors.count ? floors[level + 1] : nil, pointsGrade: byPoints, testsGrade: byTests)
    }
}
