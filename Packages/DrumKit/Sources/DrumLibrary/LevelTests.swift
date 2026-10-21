import DrumCore
import Foundation

public struct LevelTestItem: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let dsl: String
    public let bpm: Double
    public let duration: TimeInterval
    private let skillVi: String
    private let skillEn: String?

    /// Skill name in the app language.
    public var skill: String { L(skillVi, skillEn ?? skillVi) }

    public init(id: String, dsl: String, bpm: Double, duration: TimeInterval = 30, skill: String, skillEn: String? = nil) {
        self.id = id
        self.dsl = dsl
        self.bpm = bpm
        self.duration = duration
        skillVi = skill
        self.skillEn = skillEn
    }

    enum CodingKeys: String, CodingKey { case id, dsl, bpm, duration, skillVi = "skill", skillEn }
}

public struct Level: Sendable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let tests: [LevelTestItem]

    public init(id: Int, title: String, tests: [LevelTestItem]) {
        self.id = id
        self.title = title
        self.tests = tests
    }
}

/// Default level tests, one level per Rockschool grade (app-authored; replaced by book data from PrivateLibrary when present).
public enum LevelCatalog {
    /// A test passes only when its best score is strictly above this.
    public static let passMark = 90.0

    /// Recomputed on access so titles follow the current app language.
    public static var levels: [Level] { [
        Level(id: 1, title: L("Cấp độ 1 · nốt đen, móc đơn, móc kép", "Level 1 · quarters, 8ths, 16ths"), tests: [
            t("L1-singles8", "Đánh đơn móc đơn (Single Stroke)", en: "Single strokes, 8ths", "SN: xxxxxxxx\nST: RLRLRLRL", grid: 2, bpm: 70),
            t("L1-doubles8", "Đánh kép móc đơn (Double Stroke)", en: "Double strokes, 8ths", "SN: xxxxxxxx\nST: RRLLRRLL", grid: 2, bpm: 70),
            t("L1-singles16", "Đánh đơn móc kép (Single Stroke)", en: "Single strokes, 16ths", "SN: xxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRL", grid: 4, bpm: 70),
            t("L1-paradiddle", "Paradiddle móc kép", en: "Paradiddle, 16ths", "SN: xxxxxxxxxxxxxxxx\nST: RLRRLRLLRLRRLRLL", grid: 4, bpm: 70),
        ]),
        Level(id: 2, title: L("Cấp độ 2 · nhấn, flam, chùm ba", "Level 2 · accents, flams, triplets"), tests: [
            t("L2-paradiddleAcc", "Paradiddle có nhấn (accent)", en: "Accented paradiddle", "SN: XxxxXxxxXxxxXxxx\nST: RLRRLRLLRLRRLRLL", grid: 4, bpm: 70),
            t("L2-flams", "Flam nốt đen (Flam)", en: "Quarter-note flams", "SN: ffff\nST: RLRL", grid: 1, bpm: 70),
            t("L2-triplets", "Chùm ba có nhấn (Triplet)", en: "Accented triplets", "SN: XxxXxxXxxXxx\nST: RLRLRLRLRLRL", grid: 3, bpm: 70),
            t("L2-groove", "Groove rock móc đơn", en: "8th-note rock groove", "HH: x-x-x-x-x-x-x-x-\nSN: ----X-------X---\nBD: x-------x-x-----", grid: 4, bpm: 70),
        ]),
        Level(id: 3, title: L("Cấp độ 3 · đánh đơn/kép quanh tom, flam & drag", "Level 3 · singles/doubles around the toms, flams & drags"), tests: [
            t("L3-doublesToms", "Đánh kép quanh tom (Double Stroke)", en: "Double strokes around the toms", "SN: xxxx------------\nT1: ----xxxx--------\nT2: --------xxxx----\nFT: ------------xxxx\nST: RRLLRRLLRRLLRRLL", grid: 4, bpm: 75),
            t("L3-flamDrag", "Flam và drag", en: "Flams and drags", "SN: fdfd\nST: RLRL", grid: 1, bpm: 75),
            t("L3-tripletToms", "Chùm ba nhấn trên tom", en: "Triplets accented on toms", "SN: -xx-xx-xx-xx\nT1: X-----X-----\nT2: ---X-----X--\nST: RLLRLLRLLRLL", grid: 3, bpm: 75),
            t("L3-funk", "Groove funk có nốt ma", en: "Funk groove with ghost notes", "HH: x-x-x-x-x-x-x-x-\nSN: ----X--g-g--X---\nBD: x-----x---x-----", grid: 4, bpm: 75),
        ]),
        Level(id: 4, title: L("Cấp độ 4 · paradiddle ba, flam gõ kép, tay–chân", "Level 4 · triple paradiddle, flam taps, hands & feet"), tests: [
            t("L4-tripleParadiddle", "Paradiddle ba (Triple Paradiddle)", en: "Triple paradiddle", "SN: XxxxxxxxXxxxxxxx\nST: RLRLRLRRLRLRLRLL", grid: 4, bpm: 75),
            t("L4-flamTap", "Flam gõ kép (Flam Tap)", en: "Flam taps", "SN: fxfxfxfx\nST: RRLLRRLL", grid: 2, bpm: 75),
            t("L4-handsFeet", "Phối hợp tay–chân móc kép", en: "Hands & feet, 16ths", "SN: xx--xx--xx--xx--\nBD: --xx--xx--xx--xx\nST: RLFFRLFFRLFFRLFF", grid: 4, bpm: 75),
        ]),
        Level(id: 5, title: L("Cấp độ 5 · shuffle, hi-hat móc kép, nốt ma", "Level 5 · shuffle, 16th hi-hats, ghost notes"), tests: [
            t("L5-shuffle", "Nhịp shuffle", en: "Shuffle", "HH: x-xx-xx-xx-x\nSN: ---X-----X--\nBD: x-----x-----", grid: 3, bpm: 90),
            t("L5-hats16", "Hi-hat móc kép", en: "16th-note hi-hat", "HH: xxxxxxxxxxxxxxxx\nSN: ----X-------X---\nBD: x--x--x-x-------", grid: 4, bpm: 85),
            t("L5-ghost", "Groove có nốt ma (ghost note)", en: "Ghost note groove", "HH: x-x-x-x-x-x-x-x-\nSN: --g-X-g---g-X--g\nBD: x-----x---x-----", grid: 4, bpm: 85),
        ]),
        Level(id: 6, title: L("Cấp độ 6 · linear, cuộn, fill quanh tom", "Level 6 · linear, rolls, tom fills"), tests: [
            t("L6-linear", "Linear tay–chân (không trùng nốt)", en: "Linear hands & feet", "SN: -xx--xx--xx--xx-\nBD: x--xx--xx--xx--x\nST: FRLFFRLFFRLFFRLF", grid: 4, bpm: 90),
            t("L6-fiveStroke", "Five stroke roll", en: "Five stroke roll", "SN: xxxxX---xxxxX---\nST: RRLLR---LLRRL---", grid: 4, bpm: 90),
            t("L6-tomFill", "Fill móc kép quanh tom", en: "16th-note tom fill", "SN: xxxx------------\nT1: ----xxxx--------\nT2: --------xxxx----\nFT: ------------xxxx\nST: RLRLRLRLRLRLRLRL", grid: 4, bpm: 100),
        ]),
        Level(id: 7, title: L("Cấp độ 7 · nhịp lẻ, chùm sáu", "Level 7 · odd time, sextuplets"), tests: [
            t("L7-sevenEight", "Groove nhịp 7/8", en: "7/8 groove", "HH: xxxxxxx\nSN: --X--X-\nBD: x--x---", grid: 1, bpm: 100, time: "7/8"),
            t("L7-fiveFour", "Groove nhịp 5/4", en: "5/4 groove", "HH: xxxxxxxxxx\nSN: --X---X---\nBD: x---x---x-", grid: 2, bpm: 100, time: "5/4"),
            t("L7-sextuplet", "Đánh đơn chùm sáu (Sextuplet)", en: "Sextuplet single strokes", "SN: xxxxxxxxxxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRLRLRLRLRL", grid: 6, bpm: 80),
        ]),
        Level(id: 8, title: L("Cấp độ 8 · tổng hợp mức Grade 8", "Level 8 · Grade 8 mix"), tests: [
            t("L8-singles120", "Đánh đơn móc kép nhanh", en: "Fast 16th single strokes", "SN: xxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRL", grid: 4, bpm: 120),
            t("L8-displacement", "Dời phách snare (displacement)", en: "Displaced backbeat", "HH: x-x-x-x-x-x-x-x-\nSN: -----X------X---\nBD: x-----x-x-------", grid: 4, bpm: 110),
            t("L8-reading", "Đọc nhạc móc kép", en: "Reading: 16ths", "SN: x-x-xxxxx---x-x-|x---xx-xx-x-x---", grid: 4, bpm: 110),
        ]),
    ] }

    /// tempo × the densest subdivision in the exercise (notes per quarter).
    public static func difficulty(_ item: LevelTestItem) throws -> Double {
        let ex = try ExerciseDSL.parse(item.dsl)
        let positions = Array(Set(ex.notes.map(\.position))).sorted()
        let gap = zip(positions, positions.dropFirst()).map { ($1 - $0).doubleValue }.min() ?? 1
        return item.bpm / gap
    }

    private static func t(_ id: String, _ title: String, en: String, _ lines: String, grid: Int, bpm: Double, time: String = "4/4") -> LevelTestItem {
        LevelTestItem(id: id, dsl: "title: \(title)\ntitle_en: \(en)\ntime: \(time)\ntempo: \(Int(bpm))-\(Int(bpm))\ngrid: \(grid)\n\(lines)", bpm: bpm, skill: title, skillEn: en)
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
