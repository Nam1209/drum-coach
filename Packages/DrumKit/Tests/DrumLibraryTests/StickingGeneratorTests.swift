import DrumCore
import Testing
@testable import DrumLibrary

private func sticking(_ e: Exercise) -> String { e.notes.compactMap { $0.hand?.rawValue }.joined() }

@Test func allEightNoteCombinations() {
    let all = StickingGenerator.singleBeat(length: 8, subdivision: 2, balancedOnly: false)
    #expect(all.count == 256)
    #expect(Set(all.map(sticking)).count == 256)
    #expect(sticking(all[0]) == "RLRLRLRL")       // fewest same-hand repeats first, R before L
    #expect(sticking(all[1]) == "LRLRLRLR")
    #expect(all[0].bars == 1)
    #expect(all[0].notes.allSatisfy { $0.voice == .snare })
}

@Test func balancedOnlyHasEqualHands() {
    let b = StickingGenerator.singleBeat(length: 8, subdivision: 2, balancedOnly: true)
    #expect(b.count == 70)
    #expect(b.allSatisfy { sticking($0).filter { $0 == "R" }.count == 4 })
}

@Test func sixteenthsFillBars() {
    let e = StickingGenerator.singleBeat(length: 8, subdivision: 4, balancedOnly: false)[0]
    #expect(e.bars == 1)
    #expect(e.notes.count == 8)
    #expect(e.notes[1].position == Rational(1, 4))
}

@Test func triplets() {
    let t = StickingGenerator.triplets(length: 6)
    #expect(t.count == 64)
    #expect(t[0].notes[1].position == Rational(1, 3))
}

@Test func accents() {
    let base = StickingGenerator.singleBeat(length: 8, subdivision: 2, balancedOnly: false)[0]
    let a = StickingGenerator.withAccents(base, accentEvery: 4, offset: 0)
    #expect(a.notes.map { $0.articulation == .accent } == [true, false, false, false, true, false, false, false])
}

@Test func orchestrate() {
    let base = StickingGenerator.singleBeat(length: 8, subdivision: 2, balancedOnly: false)[0]
    let o = StickingGenerator.orchestrate(base, rightHand: .hiHat, leftHand: .snare)
    #expect(o.notes.filter { $0.hand == .right }.allSatisfy { $0.voice == .hiHat })
    #expect(o.notes.filter { $0.hand == .left }.allSatisfy { $0.voice == .snare })
}

@Test func randomIsDeterministic() {
    let a = StickingGenerator.random(seed: 1, bars: 4, subdivision: 2, rests: true)
    let b = StickingGenerator.random(seed: 1, bars: 4, subdivision: 2, rests: true)
    #expect(a.notes == b.notes)
    #expect(a.bars == 4)
    #expect(StickingGenerator.random(seed: 2, bars: 4, subdivision: 2, rests: true).notes != a.notes)
}

@Test func generatedExercisesHaveStableDistinctIds() {
    let a = StickingGenerator.singleBeat(length: 8, subdivision: 2, balancedOnly: false)
    let b = StickingGenerator.singleBeat(length: 8, subdivision: 2, balancedOnly: false)
    #expect(a.map(\.id) == b.map(\.id))
    #expect(Set(a.map(\.id)).count == a.count)
    #expect(StickingGenerator.random(seed: 4, bars: 4, subdivision: 2, rests: true).id == StickingGenerator.random(seed: 4, bars: 4, subdivision: 2, rests: true).id)
    let acc = StickingGenerator.withAccents(a[0], accentEvery: 4, offset: 0)
    let orch = StickingGenerator.orchestrate(a[0], rightHand: .hiHat, leftHand: .snare)
    #expect(Set([a[0].id, acc.id, orch.id]).count == 3)
}
