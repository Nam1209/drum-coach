import DrumCore
import Foundation

public struct LevelTestItem: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let dsl: String
    public let bpm: Double
    public let duration: TimeInterval
    public let skill: String

    public init(id: String, dsl: String, bpm: Double, duration: TimeInterval = 30, skill: String) {
        self.id = id
        self.dsl = dsl
        self.bpm = bpm
        self.duration = duration
        self.skill = skill
    }
}

public struct Level: Sendable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let tests: [LevelTestItem]
}

/// Default level tests, one level per Rockschool grade (app-authored; replaced by book data from PrivateLibrary when present).
public enum LevelCatalog {
    /// A test passes only when its best score is strictly above this.
    public static let passMark = 90.0

    public static let levels: [Level] = [
        Level(id: 1, title: "Level 1 · nốt đen, móc đơn, móc kép", tests: [
            t("L1-singles8", "Single stroke móc đơn", "SN: xxxxxxxx\nST: RLRLRLRL", grid: 2, bpm: 70),
            t("L1-doubles8", "Double stroke móc đơn", "SN: xxxxxxxx\nST: RRLLRRLL", grid: 2, bpm: 70),
            t("L1-singles16", "Single stroke móc kép", "SN: xxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRL", grid: 4, bpm: 70),
            t("L1-paradiddle", "Paradiddle móc kép", "SN: xxxxxxxxxxxxxxxx\nST: RLRRLRLLRLRRLRLL", grid: 4, bpm: 70),
        ]),
        Level(id: 2, title: "Level 2 · accent, flam, chùm ba", tests: [
            t("L2-paradiddleAcc", "Paradiddle có accent", "SN: XxxxXxxxXxxxXxxx\nST: RLRRLRLLRLRRLRLL", grid: 4, bpm: 70),
            t("L2-flams", "Flam nốt đen", "SN: ffff\nST: RLRL", grid: 1, bpm: 70),
            t("L2-triplets", "Chùm ba móc đơn có accent", "SN: XxxXxxXxxXxx\nST: RLRLRLRLRLRL", grid: 3, bpm: 70),
            t("L2-groove", "Groove rock 8th", "HH: x-x-x-x-x-x-x-x-\nSN: ----X-------X---\nBD: x-------x-x-----", grid: 4, bpm: 70),
        ]),
        Level(id: 3, title: "Level 3 · single/double quanh tom, flam & drag", tests: [
            t("L3-doublesToms", "Double stroke quanh tom", "SN: xxxx------------\nT1: ----xxxx--------\nT2: --------xxxx----\nFT: ------------xxxx\nST: RRLLRRLLRRLLRRLL", grid: 4, bpm: 75),
            t("L3-flamDrag", "Flam và drag", "SN: fdfd\nST: RLRL", grid: 1, bpm: 75),
            t("L3-tripletToms", "Chùm ba accent trên tom", "SN: -xx-xx-xx-xx\nT1: X-----X-----\nT2: ---X-----X--\nST: RLLRLLRLLRLL", grid: 3, bpm: 75),
            t("L3-funk", "Groove funk ghost note", "HH: x-x-x-x-x-x-x-x-\nSN: ----X--g-g--X---\nBD: x-----x---x-----", grid: 4, bpm: 75),
        ]),
        Level(id: 4, title: "Level 4 · triple paradiddle, flam tap, tay–chân", tests: [
            t("L4-tripleParadiddle", "Triple paradiddle", "SN: XxxxxxxxXxxxxxxx\nST: RLRLRLRRLRLRLRLL", grid: 4, bpm: 75),
            t("L4-flamTap", "Flam tap", "SN: fxfxfxfx\nST: RRLLRRLL", grid: 2, bpm: 75),
            t("L4-handsFeet", "Tay–chân móc kép", "SN: xx--xx--xx--xx--\nBD: --xx--xx--xx--xx\nST: RLFFRLFFRLFFRLFF", grid: 4, bpm: 75),
        ]),
        Level(id: 5, title: "Level 5 · shuffle, hi-hat 16th, ghost", tests: [
            t("L5-shuffle", "Shuffle", "HH: x-xx-xx-xx-x\nSN: ---X-----X--\nBD: x-----x-----", grid: 3, bpm: 90),
            t("L5-hats16", "Hi-hat móc kép", "HH: xxxxxxxxxxxxxxxx\nSN: ----X-------X---\nBD: x--x--x-x-------", grid: 4, bpm: 85),
            t("L5-ghost", "Ghost note groove", "HH: x-x-x-x-x-x-x-x-\nSN: --g-X-g---g-X--g\nBD: x-----x---x-----", grid: 4, bpm: 85),
        ]),
        Level(id: 6, title: "Level 6 · linear, roll, fill quanh tom", tests: [
            t("L6-linear", "Linear tay–chân", "SN: -xx--xx--xx--xx-\nBD: x--xx--xx--xx--x\nST: FRLFFRLFFRLFFRLF", grid: 4, bpm: 90),
            t("L6-fiveStroke", "Five stroke roll", "SN: xxxxX---xxxxX---\nST: RRLLR---LLRRL---", grid: 4, bpm: 90),
            t("L6-tomFill", "Fill móc kép quanh tom", "SN: xxxx------------\nT1: ----xxxx--------\nT2: --------xxxx----\nFT: ------------xxxx\nST: RLRLRLRLRLRLRLRL", grid: 4, bpm: 100),
        ]),
        Level(id: 7, title: "Level 7 · nhịp lẻ, sextuplet", tests: [
            t("L7-sevenEight", "Groove 7/8", "HH: xxxxxxx\nSN: --X--X-\nBD: x--x---", grid: 1, bpm: 100, time: "7/8"),
            t("L7-fiveFour", "Groove 5/4", "HH: xxxxxxxxxx\nSN: --X---X---\nBD: x---x---x-", grid: 2, bpm: 100, time: "5/4"),
            t("L7-sextuplet", "Sextuplet single stroke", "SN: xxxxxxxxxxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRLRLRLRLRL", grid: 6, bpm: 80),
        ]),
        Level(id: 8, title: "Level 8 · tổng hợp mức Grade 8", tests: [
            t("L8-singles120", "Single stroke 16th nhanh", "SN: xxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRL", grid: 4, bpm: 120),
            t("L8-displacement", "Backbeat lệch", "HH: x-x-x-x-x-x-x-x-\nSN: -----X------X---\nBD: x-----x-x-------", grid: 4, bpm: 110),
            t("L8-reading", "Đọc nhạc 16th", "SN: x-x-xxxxx---x-x-|x---xx-xx-x-x---", grid: 4, bpm: 110),
        ]),
    ]

    /// tempo × the densest subdivision in the exercise (notes per quarter).
    public static func difficulty(_ item: LevelTestItem) throws -> Double {
        let ex = try ExerciseDSL.parse(item.dsl)
        let positions = Array(Set(ex.notes.map(\.position))).sorted()
        let gap = zip(positions, positions.dropFirst()).map { ($1 - $0).doubleValue }.min() ?? 1
        return item.bpm / gap
    }

    private static func t(_ id: String, _ title: String, _ lines: String, grid: Int, bpm: Double, time: String = "4/4") -> LevelTestItem {
        LevelTestItem(id: id, dsl: "title: \(title)\ntime: \(time)\ntempo: \(Int(bpm))-\(Int(bpm))\ngrid: \(grid)\n\(lines)", bpm: bpm, skill: title)
    }
}

public struct LevelProgress: Sendable {
    public let bestScores: [String: Double]
    private let levels: [Level]

    public init(bestScores: [String: Double], levels: [Level] = LevelCatalog.levels) {
        self.bestScores = bestScores
        self.levels = levels
    }

    public func isPassed(_ test: LevelTestItem) -> Bool { (bestScores[test.id] ?? 0) > LevelCatalog.passMark }
    public func isPassed(_ level: Level) -> Bool { !level.tests.isEmpty && level.tests.allSatisfy(isPassed) }

    /// Highest level whose lower levels are all passed too (0 = none).
    public var currentLevel: Int {
        var n = 0
        for l in levels.sorted(by: { $0.id < $1.id }) { if isPassed(l) { n = l.id } else { break } }
        return n
    }

    /// Before any attempt every level is open (to find a starting point); afterwards only up to the next level.
    public func isUnlocked(_ level: Level) -> Bool {
        bestScores.isEmpty || level.id <= currentLevel + 1
    }
}
