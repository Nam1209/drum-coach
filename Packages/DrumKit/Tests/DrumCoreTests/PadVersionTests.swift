import Testing
@testable import DrumCore

private let groove = try! ExerciseDSL.parse("""
title: Groove
time: 4/4
grid: 2
HH: xxxxxxxx
SN: --X---x-
BD: x---x---
ST: RRRRRRRR
""")
private let strokes = try! ExerciseDSL.parse("title: Strokes\ntime: 4/4\ngrid: 2\nSN: xxxxxxxx\nST: RLRLRLRL")

@Test func onlyOneSurfaceExercisesFitAPad() {
    #expect(!strokes.needsKit)
    #expect(groove.needsKit)
}

@Test func padVersionKeepsTheHandsOnOneSurface() {
    let pad = groove.padVersion()
    #expect(!pad.needsKit)
    #expect(pad.notes.allSatisfy { $0.voice == .snare })
    #expect(pad.notes.count == 8)                                   // feet dropped; hi-hat + snare on beat 2 and 4 merge
    #expect(pad.notes.map(\.position) == (0..<8).map { Rational($0, 2) })
    #expect(pad.notes[2].articulation == .accent)                   // the accented snare wins over the hi-hat stroke
    #expect(pad.notes.allSatisfy { $0.hand == .right })
    #expect(pad.title.contains("pad"))
    #expect(pad.id != groove.id)
}

@Test func padVersionOfAPadExerciseIsItself() {
    #expect(strokes.padVersion() == strokes)
}
