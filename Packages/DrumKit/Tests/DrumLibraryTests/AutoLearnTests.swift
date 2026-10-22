import DrumCore
import Testing
@testable import DrumLibrary

private func bars(_ n: Int) throws -> Exercise {
    try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: " + Array(repeating: "xxxx", count: n).joined(separator: "|"))
}

@Test func planBuildsSegmentsChainsThenWholeExercise() throws {
    let plan = AutoLearnPlan(exercise: try bars(8), barsPerSegment: 2)
    #expect(plan.steps.prefix(4).map(\.bars) == [1...2, 3...4, 5...6, 7...8])
    #expect(plan.steps.contains { $0.bars == 1...4 })            // pairs of segments
    #expect(plan.steps.contains { $0.bars == 5...8 })
    let last2 = plan.steps.suffix(2)
    #expect(last2.allSatisfy { $0.bars == 1...8 })
    #expect(last2.map(\.withClick) == [true, false])                // whole piece with, then without click
}

@Test func shortExerciseSkipsToWholePiece() throws {
    let plan = AutoLearnPlan(exercise: try bars(1), barsPerSegment: 2)
    #expect(plan.steps.map(\.bars) == [1...1, 1...1])
}

@Test func adaptiveTempo() {
    var t = AdaptiveTempo(target: 100)
    #expect(t.bpm == 50)
    #expect(t.record(score: 95) == 55)
    for _ in 0..<2 { _ = t.record(score: 50) }
    #expect(t.bpm == 55)
    #expect(t.record(score: 50) == 45)            // third fail in a row
    for _ in 0..<20 { _ = t.record(score: 100) }
    #expect(t.bpm == 100 && t.atTarget)
    var low = AdaptiveTempo(target: 60)
    for _ in 0..<12 { _ = low.record(score: 0) }
    #expect(low.bpm == 18)                        // never below 30% of target
}

@Test func kickPermutations() throws {
    let base = try ExerciseDSL.parse("time: 4/4\ngrid: 2\nHH: xxxxxxxx\nSN: --x---x-\nBD: x-------")
    let perms = StickingGenerator.kickPermutations(base)
    #expect(perms.count == 5)                     // kick added on each free 8th: positions 1, 3, 4, 5, 7
    #expect(perms.allSatisfy { $0.notes.filter { $0.voice == .kick }.count == 2 })
    #expect(perms.allSatisfy { $0.notes.filter { $0.voice == .snare }.count == 2 })
    #expect(Set(perms.map(\.id)).count == 5)
    #expect(StickingGenerator.snarePermutations(base).allSatisfy { $0.notes.filter { $0.voice == .snare }.count == 3 })
}
