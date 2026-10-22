import DrumCore
import Testing
@testable import DrumLibrary

@Test func grooveRecallIsTwoBarsOfKit() {
    let t = EarTest(kind: .grooveRecall, grade: 1, seed: 7)
    #expect(t.prompt.bars == 2)
    #expect(Set(t.prompt.notes.map(\.voice)).isSubset(of: [.hiHat, .snare, .kick]))
    #expect(t.prompt.notes.contains { $0.voice == .snare } && t.prompt.notes.contains { $0.voice == .kick })
    #expect(EarTest(kind: .grooveRecall, grade: 1, seed: 7).prompt.notes == t.prompt.notes)
}

@Test func fillPlaybackHasTwoDistinctChoices() {
    let t = EarTest(kind: .fillPlayback, grade: 2, seed: 3)
    #expect(t.choices.count == 2)
    #expect(t.choices[0].notes != t.choices[1].notes)
    #expect(t.choices[t.correctIndex].notes == t.prompt.notes)
    #expect(t.prompt.notes.allSatisfy { $0.voice == .snare })
    #expect(t.bpm == 70)
}

@Test func earTestScoring() {
    let t = EarTest(kind: .fillPlayback, grade: 1, seed: 1)
    #expect(t.score(playedScore: 100, chosenIndex: t.correctIndex) == 100)
    #expect(t.score(playedScore: 100, chosenIndex: 1 - t.correctIndex) == 70)
    #expect(t.score(playedScore: 50, chosenIndex: nil) == 35)
    #expect(EarTest(kind: .grooveRecall, grade: 1, seed: 1).score(playedScore: 80, chosenIndex: nil) == 80)
}

@Test func gmqAnswersAreValid() {
    for grade in 1...8 {
        let qs = GMQuiz.questions(grade: grade, seed: 5)
        #expect(qs.count == 5, "grade \(grade)")
        #expect(qs.allSatisfy { (0..<$0.options.count).contains($0.answer) && $0.options.count >= 2 })
        #expect(qs.allSatisfy { $0.grade <= grade })
    }
    #expect(GMQuiz.questions(grade: 1, seed: 5).map(\.text) == GMQuiz.questions(grade: 1, seed: 5).map(\.text))
}

@Test func midiLearn() {
    var m = MIDILearn()
    #expect(m.received(note: 38) == nil)
    m.expect(.snare)
    #expect(m.received(note: 38) == .snare)
    #expect(m.map[38] == .snare)
    #expect(m.received(note: 38) == .snare)
    m.expect(.kick)
    _ = m.received(note: 36)
    #expect(m.map == [38: .snare, 36: .kick])
}
