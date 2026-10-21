import DrumCore
import Testing
@testable import DrumAI

private let groove = try! ExerciseDSL.parse("title: Groove\ntime: 4/4\ngrid: 2\nHH: xxxxxxxx\nSN: --x---x-\nBD: x---x---\nST: RRRRRRRR")
private let strokes = try! ExerciseDSL.parse("title: Strokes\ntime: 4/4\ngrid: 2\nSN: xxxxxxxx\nST: RLRLRLRL")
private let catalog = ["groove": groove, "strokes": strokes]
private func item(_ id: String) -> PlannedItem { PlannedItem(exerciseId: id, newExerciseDSL: nil, bpm: 70, minutes: 5, focus: "f") }
private let day = DayPlan(day: 1, warmup: [item("groove")], main: [item("strokes"), item("groove")], fun: [item("groove")])

@Test func padDaysTurnKitExercisesIntoPadVersions() throws {
    let pad = day.adapted(to: .pad, catalog: catalog)
    #expect(pad.main[0] == item("strokes"))                         // already fits the pad
    let swapped = pad.main[1]
    #expect(swapped.exerciseId == nil)
    let ex = try ExerciseDSL.parse(try #require(swapped.newExerciseDSL))
    #expect(!ex.needsKit)
    #expect(swapped.bpm == 70 && swapped.minutes == 5 && swapped.focus == "f")
}

@Test func kitDaysAreUnchanged() {
    #expect(day.adapted(to: .kit, catalog: catalog) == day)
}

@Test func bothWarmsUpOnThePadAndPlaysTheRestOnTheKit() {
    let both = day.adapted(to: .both, catalog: catalog)
    #expect(both.warmup[0].exerciseId == nil)
    #expect(both.main == day.main && both.fun == day.fun)
    #expect(DayPlan.surface(forSegment: 0, on: .both) == .pad)
    #expect(DayPlan.surface(forSegment: 1, on: .both) == .kit)
    #expect(DayPlan.surface(forSegment: 2, on: .pad) == .pad)
    #expect(DayPlan.surface(forSegment: 0, on: .kit) == .kit)
}
