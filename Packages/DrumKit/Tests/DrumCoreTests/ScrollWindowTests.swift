import Testing
@testable import DrumCore

@Test func scrollLayoutIsLinearAcrossBarLines() throws {
    // Without bar padding a note's x is exactly its beat × pixels per beat, so a line moving at constant speed
    // never jumps at a bar line (with padding the playhead skipped 2 × 8% of a bar there).
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 2\nSN: xxxxxxxx|xxxxxxxx\nST: RLRLRLRL|RLRLRLRL")
    let l = NotationLayout(exercise: ex, barWidth: 400, barsPerLine: 2, staffSpacing: 10, padding: 0)
    for g in l.glyphs {
        #expect(abs(g.x - ex.notes[g.noteIndex].position.doubleValue * 100) < 1e-9)
    }
    let endOfBar1 = l.playheadX(atBeat: Rational(3999, 1000)).x, startOfBar2 = l.playheadX(atBeat: Rational(4, 1)).x
    #expect(abs(startOfBar2 - endOfBar1) < 0.2)
}

@Test func mainNoteLengthIsTheMostCommonGap() throws {
    #expect(ScrollWindow.mainNoteLength(try ExerciseDSL.parse("time: 4/4\ngrid: 2\nSN: xxxxxxxx")) == 0.5)
    #expect(ScrollWindow.mainNoteLength(try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: xxxx")) == 1)
    #expect(ScrollWindow.mainNoteLength(try ExerciseDSL.parse("time: 4/4\ngrid: 4\nSN: xxxxxxxxxxxxxxxx")) == 0.25)
    // Mostly eighths with one pair of sixteenths: eighths win.
    #expect(ScrollWindow.mainNoteLength(try ExerciseDSL.parse("time: 4/4\ngrid: 4\nSN: x-x-x-x-x-x-x-xx")) == 0.5)
    // Two notes a bar apart: the gap that wraps to the next pass counts too.
    #expect(ScrollWindow.mainNoteLength(try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: x-x-")) == 2)
}

@Test func eightMainNotesFitRightOfThePlayhead() throws {
    let eighths = try ExerciseDSL.parse("time: 4/4\ngrid: 2\nSN: xxxxxxxx")
    let ppb = ScrollWindow.pixelsPerBeat(width: 1000, exercise: eighths)
    // 8 eighths = 4 beats across the 80% of the width right of the playhead.
    #expect(abs(ppb - 200) < 1e-9)
}

@Test func repeatsCoverTheVisibleWindowAndStopAtTheLastPass() {
    // 1-bar exercise (4 beats): at beat 6 with 1 beat behind and 4 ahead, passes 1 and 2 are on screen.
    #expect(ScrollWindow.repeats(beat: 6, lengthBeats: 4, behindBeats: 1, aheadBeats: 4, lastRepeat: 9) == 1...2)
    // During the count-in only the first pass shows.
    #expect(ScrollWindow.repeats(beat: -4, lengthBeats: 4, behindBeats: 1, aheadBeats: 4, lastRepeat: 9) == 0...0)
    // Nothing is drawn past the run's last pass.
    #expect(ScrollWindow.repeats(beat: 38, lengthBeats: 4, behindBeats: 1, aheadBeats: 4, lastRepeat: 9) == 9...9)
    #expect(ScrollWindow.repeats(beat: 45, lengthBeats: 4, behindBeats: 1, aheadBeats: 4, lastRepeat: 9) == nil)
}
