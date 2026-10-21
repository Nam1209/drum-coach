import DrumCore
import Testing
@testable import DrumLibrary

@Test(.vietnamese) func voiceNamesAreVietnamese() {
    #expect(Voice.kick.displayName == "TRỐNG BASS")
    #expect(Voice.snare.displayName == "SNARE")
    #expect(Voice.floorTom.displayName == "TOM SÀN")
    #expect(Voice.hiHatPedal.localizedName == "Hi-hat chân")
}

@Test(.vietnamese) func rudimentsShowVietnameseWithOriginalName() {
    #expect(PASRudiments.all[0].title == "1. Cuộn đơn (Single Stroke Roll)")
    #expect(PASRudiments.all[15].title == "16. Paradiddle đơn (Single Paradiddle)")
    #expect(PASRudiments.all.allSatisfy { $0.title.contains("(") })
}

@Test(.vietnamese) func generatedTitlesAreVietnamese() {
    #expect(StickingGenerator.singleBeat(length: 4, subdivision: 2, balancedOnly: false)[0].title.hasPrefix("Tổ hợp tay #1"))
    #expect(StickingGenerator.triplets(length: 3)[0].title.hasPrefix("Chùm ba #1"))
}

@Test(.vietnamese) func curriculumAndLevelTitlesHaveNoBareEnglish() throws {
    let english = ["Single Stroke 16th", "Double Stroke 16th", "Rock 8th", "Hi-hat 16th", "Triplet single stroke", "Sextuplet single stroke",
                   "Groove 7/8", "Groove 5/4", "Groove 12/8", "Five Stroke Roll", "Shuffle\n"]
    for unit in Grade8Curriculum.units {
        for dsl in unit.exercises { let t = try ExerciseDSL.parse(dsl).title; #expect(!english.contains(t), "\(t)") }
    }
    for level in LevelCatalog.levels { for t in level.tests { #expect(!english.contains(try ExerciseDSL.parse(t.dsl).title)) } }
}

/// Runs a test with the app language forced to Vietnamese (task-local, safe with parallel tests).
struct VietnameseTrait: TestTrait, TestScoping {
    func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await Lang.$override.withValue(.vi) { try await function() }
    }
}
extension Trait where Self == VietnameseTrait { static var vietnamese: Self { VietnameseTrait() } }

let vietnameseMarks = Set("àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ")
func hasVietnamese(_ s: String) -> Bool { s.lowercased().contains { vietnameseMarks.contains($0) } }

struct EnglishTrait: TestTrait, TestScoping {
    func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await Lang.$override.withValue(.en) { try await function() }
    }
}
extension Trait where Self == EnglishTrait { static var english: Self { EnglishTrait() } }

@Test(.english) func englishLibraryHasNoVietnamese() throws {
    var texts: [String] = PASRudiments.all.map(\.title)
    for u in Grade8Curriculum.units {
        texts += [u.title, u.skill]
        texts += try u.exercises.map { try ExerciseDSL.parse($0).title }
    }
    for l in LevelCatalog.levels {
        texts.append(l.title)
        for t in l.tests { texts += [t.skill, try ExerciseDSL.parse(t.dsl).title] }
    }
    texts += StickingGenerator.singleBeat(length: 4, subdivision: 2, balancedOnly: false).prefix(3).map(\.title)
    texts.append(StickingGenerator.random(seed: 1, bars: 1, subdivision: 2, rests: true).title)
    texts += Voice.allCases.map(\.localizedName)
    let bad = texts.filter(hasVietnamese)
    #expect(bad.isEmpty, "\(bad)")
}
