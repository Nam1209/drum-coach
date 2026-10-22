import Testing
@testable import DrumCore

@Test func glyphsPlacedInsideBar() throws {
    let ex = try ExerciseDSL.parse(paradiddleText)
    let l = NotationLayout(exercise: ex, barWidth: 400, barsPerLine: 2, staffSpacing: 10)
    #expect(l.glyphs.first!.x > 0)
    #expect(l.glyphs.allSatisfy { $0.x < 400 && $0.line == 0 })
    let atZero = l.glyphs.filter { ex.notes[$0.noteIndex].position == Rational(0, 1) }
    #expect(Set(atZero.map(\.x)).count == 1)          // HH + BD stacked on one x
    #expect(atZero.count == 2)
}

@Test func playheadInterpolates() throws {
    let ex = try ExerciseDSL.parse(paradiddleText)
    let l = NotationLayout(exercise: ex, barWidth: 400, barsPerLine: 2, staffSpacing: 10)
    let mid = l.playheadX(atBeat: Rational(2, 1))
    let start = l.playheadX(atBeat: Rational(1, 1)), end = l.playheadX(atBeat: Rational(3, 1))
    #expect(mid.line == 0)
    #expect(abs(mid.x - (start.x + end.x) / 2) < 0.001)
    #expect(l.playheadX(atBeat: Rational(4, 1)).x == l.playheadX(atBeat: Rational(0, 1)).x)   // next repeat wraps
}

@Test func linesWrap() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: xxxx|xxxx|xxxx|xxxx")
    let l = NotationLayout(exercise: ex, barWidth: 300, barsPerLine: 2, staffSpacing: 10)
    #expect(l.glyphs.last!.line == 1)
    #expect(l.lineCount == 2)
    #expect(l.playheadX(atBeat: Rational(9, 1)).line == 1)
}

@Test func beamLevels() throws {
    let sixteenths = NotationLayout(exercise: try ExerciseDSL.parse("time: 4/4\ngrid: 4\nSN: xxxxxxxxxxxxxxxx"), barWidth: 400, barsPerLine: 1, staffSpacing: 10)
    #expect(sixteenths.beams.count == 4)
    #expect(sixteenths.beams.allSatisfy { $0.level == 2 })
    let eighths = NotationLayout(exercise: try ExerciseDSL.parse("time: 4/4\ngrid: 2\nSN: xxxxxxxx"), barWidth: 400, barsPerLine: 1, staffSpacing: 10)
    #expect(eighths.beams.allSatisfy { $0.level == 1 })
    let quarters = NotationLayout(exercise: try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: xxxx"), barWidth: 400, barsPerLine: 1, staffSpacing: 10)
    #expect(quarters.beams.isEmpty)
}

@Test func ghostAndHandsCarried() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: Xg--\nST: RL--")
    let l = NotationLayout(exercise: ex, barWidth: 400, barsPerLine: 1, staffSpacing: 10)
    #expect(l.glyphs.map(\.accent) == [true, false])
    #expect(l.glyphs.map(\.ghost) == [false, true])
    #expect(l.glyphs.map(\.hand) == [.right, .left])
}

@Test func flipSwapsHands() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: xxx-\nBD: ---x\nST: RLRF")
    let f = ex.flippedHands()
    #expect(f.notes.map(\.hand) == [.left, .right, .left, .foot])
}

@Test func timelineKeepsExerciseNoteIndex() throws {
    let ex = try ExerciseDSL.parse(paradiddleText)
    let t = Timeline(exercise: ex, bpm: 100, repeats: 3, countInBars: 1)
    for tn in t.notes { #expect(ex.notes[tn.noteIndex] == tn.note) }
    #expect(t.notes.last!.repeatIndex == 2)
}

@Test func followModeKeepsTheNextLineInView() {
    // 6 lines, 2 visible: the playing line sits on top so the next one is always just below.
    #expect(NotationScroll.firstVisibleLine(current: 0, lineCount: 6, visible: 2) == 0)
    #expect(NotationScroll.firstVisibleLine(current: 1, lineCount: 6, visible: 2) == 1)
    #expect(NotationScroll.firstVisibleLine(current: 4, lineCount: 6, visible: 2) == 4)
    #expect(NotationScroll.firstVisibleLine(current: 5, lineCount: 6, visible: 2) == 4)   // last line: no empty space
    #expect(NotationScroll.firstVisibleLine(current: 0, lineCount: 1, visible: 2) == 0)
}
