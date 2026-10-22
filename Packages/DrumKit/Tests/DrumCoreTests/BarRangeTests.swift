import Testing
@testable import DrumCore

@Test func sliceKeepsChosenBarsShiftedToStart() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: x---|-x--|--x-|---x")
    let s = ex.slice(bars: 2...3)
    #expect(s.bars == 2)
    #expect(s.notes.map(\.position) == [Rational(1, 1), Rational(6, 1)])
    #expect(s.id != ex.id)
    #expect(ex.slice(bars: 2...3).id == s.id)
}

@Test func sliceClampsToExercise() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: x---|-x--")
    #expect(ex.slice(bars: 2...9).bars == 1)
    #expect(ex.slice(bars: 0...1).notes.count == 1)
}
