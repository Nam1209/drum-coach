import Testing
@testable import DrumCore

let paradiddleText = """
title: Single Paradiddle
time: 4/4
tempo: 60-120
grid: 4
HH: x-x-x-x-x-x-x-x-
SN: ----o-------o---
BD: o-------o-o-----
ST: RLRRLRLLRLRRLRLL
"""

@Test func parsesParadiddle() throws {
    let ex = try ExerciseDSL.parse(paradiddleText)
    #expect(ex.title == "Single Paradiddle")
    #expect(ex.bars == 1)
    #expect(ex.timeSignature == TimeSignature(beats: 4, unit: 4))
    #expect(ex.notes.filter { $0.voice == .hiHat }.count == 8)
    #expect(ex.notes.first { $0.voice == .snare }!.position == Rational(1, 1))
    #expect(ex.suggestedTempo == 60...120)
}

@Test func accentGhostAndSticking() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 4\nSN: Og--------------\nST: RL--------------")
    let sn = ex.notes.filter { $0.voice == .snare }.sorted { $0.position < $1.position }
    #expect(sn.count == 2)
    #expect(sn[0].articulation == .accent && sn[0].position == Rational(0, 1) && sn[0].hand == .right)
    #expect(sn[1].articulation == .ghost && sn[1].position == Rational(1, 4) && sn[1].hand == .left)
}

@Test func otherArticulations() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: fdzX")
    #expect(ex.notes.map(\.articulation) == [.flam, .drag, .buzz, .accent])
}

@Test func barLinesAndSpacesIgnored() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 2\nSN: x-x- x-x- | x-x- x-x-")
    #expect(ex.bars == 2)
    #expect(ex.notes.count == 8)
}

@Test func footStickingGoesToKick() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: -x-x\nBD: x-x-\nST: FRFL")
    #expect(ex.notes.first { $0.voice == .kick }!.hand == .foot)
    #expect(ex.notes.filter { $0.voice == .snare }.map(\.hand) == [.right, .left])
}

@Test func unequalLinesRejected() {
    #expect(throws: DSLError.unequalLineLengths) {
        try ExerciseDSL.parse("time: 4/4\ngrid: 4\nSN: o---\nBD: o-")
    }
}

@Test func missingTimeRejected() {
    #expect(throws: DSLError.missingHeader("time")) { try ExerciseDSL.parse("grid: 4\nSN: o---") }
}

@Test func unknownVoiceRejected() {
    #expect(throws: DSLError.unknownVoice("ZZ")) { try ExerciseDSL.parse("time: 4/4\ngrid: 1\nZZ: xxxx") }
}

@Test func badSymbolRejected() {
    #expect(throws: DSLError.badSymbol("q", line: 3)) { try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: xxqx") }
}

@Test func partialBarRejected() {
    #expect(throws: DSLError.lengthNotMultipleOfBar) { try ExerciseDSL.parse("time: 4/4\ngrid: 4\nSN: x-x-") }
}

@Test func roundTrip() throws {
    let ex = try ExerciseDSL.parse(paradiddleText)
    let again = try ExerciseDSL.parse(ExerciseDSL.serialize(ex, grid: 4))
    #expect(Set(again.notes) == Set(ex.notes))
    #expect(again.title == ex.title && again.suggestedTempo == ex.suggestedTempo)
}

@Test func sevenEight() throws {
    let ex = try ExerciseDSL.parse("time: 7/8\ngrid: 1\nSN: x-x-x-x")
    #expect(ex.bars == 1)
    #expect(ex.timeSignature.beatsInQuarters == Rational(7, 2))
    #expect(ex.notes.last!.position == Rational(3, 1)) // 7th eighth note = quarter beat 3
}

@Test func tripletGrid() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 3\nSN: xxxxxxxxxxxx")
    #expect(ex.notes[1].position == Rational(1, 3))
}
