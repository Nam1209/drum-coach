import Testing
@testable import DrumCore

@Test func timelineAt120() throws {
    let ex = try ExerciseDSL.parse(paradiddleText)
    let t = Timeline(exercise: ex, bpm: 120, repeats: 2, countInBars: 1)
    #expect(t.notes.first!.time == 2.0)                  // count-in: 4 beats × 0.5 s
    #expect(t.notes.count == 2 * ex.notes.count)
    #expect(t.duration == 2.0 + 2 * 2.0)
    #expect(t.notes.map(\.index) == Array(0..<t.notes.count))
    #expect(zip(t.notes, t.notes.dropFirst()).allSatisfy { $0.time <= $1.time })
}

@Test func secondRepeatOffset() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: x---")
    let t = Timeline(exercise: ex, bpm: 60, repeats: 3, countInBars: 0)
    #expect(t.notes.map(\.time) == [0, 4, 8])
}

@Test func beatTimeIncludesCountIn() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: x---")
    let t = Timeline(exercise: ex, bpm: 60, repeats: 1, countInBars: 1)
    #expect(t.beatTime(Rational(1, 2)) == 4.5)
}
