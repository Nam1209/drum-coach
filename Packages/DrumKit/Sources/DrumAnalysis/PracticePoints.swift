import DrumCore

/// Points for every finished run: clean playing earns, sloppy playing costs.
/// 90%+ earns 10–20, 60–90% earns 0–5, under 60% loses up to 12. Harder timing windows earn more;
/// passing a level test adds 50.
public enum PracticePoints {
    public static let levelTestBonus = 50

    public static func points(score: Double, goodWindowMs: Double, isLevelTest: Bool) -> Int {
        let s = min(100, max(0, score))
        if s < 60 { return -Int(((60 - s) / 5).rounded(.up)) }
        let base = s >= 90 ? 10 + Int((s - 90).rounded()) : Int(((s - 60) / 6).rounded())
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
