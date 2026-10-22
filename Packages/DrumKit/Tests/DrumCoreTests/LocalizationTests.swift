import Testing
@testable import DrumCore

@Suite(.serialized) struct LocalizationTests {
    @Test func defaultFollowsDeviceLanguage() {
        #expect(AppLanguage.systemDefault(preferred: ["vi-VN", "en-US"]) == .vi)
        #expect(AppLanguage.systemDefault(preferred: ["en-GB"]) == .en)
        #expect(AppLanguage.systemDefault(preferred: ["fr-FR", "vi"]) == .en)   // first language decides; non-Vietnamese → English
        #expect(AppLanguage.systemDefault(preferred: []) == .en)
    }

    @Test func pickTextByLanguage() {
        Lang.$override.withValue(.vi) { #expect(L("Xin chào", "Hello") == "Xin chào") }
        Lang.$override.withValue(.en) { #expect(L("Xin chào", "Hello") == "Hello") }
    }

    @Test func globalSettingIsUsedWithoutOverride() {
        let old = Lang.current
        defer { Lang.current = old }
        Lang.current = .en
        #expect(Lang.$override.withValue(nil) { L("a", "b") } == "b")
    }

    @Test func englishTitleInDSL() throws {
        let text = "title: Cuộn đơn\ntitle_en: Single stroke roll\ntime: 4/4\ngrid: 1\nSN: xxxx"
        let vi = try Lang.$override.withValue(.vi) { try ExerciseDSL.parse(text) }
        let en = try Lang.$override.withValue(.en) { try ExerciseDSL.parse(text) }
        #expect(vi.title == "Cuộn đơn" && en.title == "Single stroke roll")
        #expect(vi.id == en.id)   // the language never changes an exercise's identity
        #expect(try ExerciseDSL.parse("title: Chỉ tiếng Việt\ntime: 4/4\ngrid: 1\nSN: xxxx").title == "Chỉ tiếng Việt")
    }

    @Test func idIgnoresTitle() throws {
        let a = try ExerciseDSL.parse("title: A\ntime: 4/4\ngrid: 1\nSN: xxxx")
        let b = try ExerciseDSL.parse("title: B\ntime: 4/4\ngrid: 1\nSN: xxxx")
        #expect(a.id == b.id)
    }

    @Test func voiceNamesFollowLanguage() {
        Lang.$override.withValue(.en) { #expect(Voice.kick.localizedName == "Bass drum" && Voice.floorTom.displayName == "FLOOR TOM") }
        Lang.$override.withValue(.vi) { #expect(Voice.kick.localizedName == "Trống bass") }
    }
}
