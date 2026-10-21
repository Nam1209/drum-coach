import DrumCore
import Testing
@testable import DrumAnalysis

@Test func gradeColors() {
    let r = ScoringRules()
    #expect(r.grade(.hit(offset: 0.029, velocity: 1)) == .good)
    #expect(r.grade(.hit(offset: -0.031, velocity: 1)) == .early)
    #expect(r.grade(.hit(offset: 0.05, velocity: 1)) == .late)
    #expect(r.grade(.wrongVoice(offset: 0.0, played: .tom1)) == .late)
    #expect(r.grade(.missed) == .missed)
}

@Test func scorePercent() {
    let r = ScoringRules()
    let good = NoteResult.hit(offset: 0, velocity: 1)
    let eightGoodOneLateOneMissed: [NoteResult] = Array(repeating: good, count: 8) + [.hit(offset: 0.05, velocity: 1), .missed]
    #expect(r.score(eightGoodOneLateOneMissed, totalNotes: 10, extraHits: 0) == 85)
    #expect(r.score(Array(repeating: good, count: 10), totalNotes: 10, extraHits: 4) == 80)
    #expect(r.score([], totalNotes: 10, extraHits: 30) == 0)
    #expect(r.score(Array(repeating: good, count: 5), totalNotes: 10, extraHits: 0) == 50)   // unplayed notes count as missed
}

@Test func difficultyPresets() {
    #expect(ScoringRules.easy.goodWindow == 0.045)
    #expect(ScoringRules().goodWindow == 0.030)
    #expect(ScoringRules.hard.goodWindow == 0.020)
}
