import DrumAnalysis
import DrumCore
import Foundation
import Testing
@testable import DrumAI

/// Stats for 20 notes where `good` are on time, the rest early by 50 ms, with offsets jittered by `jitterMs`.
private func stats(good: Int, jitterMs: Double = 8, restMissed: Bool = false) -> SessionStats {
    let notes = (0..<20).map { TimedNote(index: $0, noteIndex: $0, repeatIndex: 0,
                                         note: NoteEvent(position: Rational($0, 2), voice: .snare, hand: $0 % 2 == 0 ? .right : .left),
                                         time: Double($0) * 0.5) }
    var r: [Int: NoteResult] = [:]
    for i in 0..<20 {
        r[i] = i < good ? .hit(offset: (i % 2 == 0 ? jitterMs : -jitterMs) / 1000, velocity: 0.8) : (restMissed ? .missed : .hit(offset: -0.05, velocity: 0.8))
    }
    return SessionStats(results: r, notes: notes, extraHits: 0)
}

private func input(_ s: SessionStats, bpm: Double = 75, target: Int = 75, grade: Int = 3) -> AssessmentInput {
    AssessmentInput(exerciseTitle: "Paradiddle", skill: "Rudiments", grade: grade, bpm: bpm, targetBpm: target, stats: s, recentHistory: [], mode: "pad")
}

@Test func localDistinction() {
    let a = AssessmentRequest.localFallback(input(stats(good: 19)))
    #expect(a.band == "Distinction")
    #expect(a.estimatedGrade == 3)
}

@Test func localBelowPass() {
    let a = AssessmentRequest.localFallback(input(stats(good: 4, restMissed: true)))
    #expect(a.band == "Below Pass")
    #expect((1...8).contains(a.estimatedGrade))
    #expect(a.estimatedGrade == 2)
}

@Test func localSlowTempoCapsBand() {
    let a = AssessmentRequest.localFallback(input(stats(good: 20), bpm: 60, target: 75))
    #expect(a.band != "Distinction")
}

@Test func gradeClamped() {
    #expect(AssessmentRequest.localFallback(input(stats(good: 2, restMissed: true), grade: 1)).estimatedGrade == 1)
    #expect(AssessmentRequest.localFallback(input(stats(good: 20), grade: 9)).estimatedGrade == 8)
}

@Test func aiAssessmentDecodes() async throws {
    let body = #"{"estimatedGrade":3,"band":"Merit","timingComment":"ok","strengths":["a"],"weaknesses":["b"],"nextSteps":["c"],"suggestedTempo":80}"#
    let escaped = String(data: try JSONEncoder().encode(body), encoding: .utf8)!
    let t = FakeTransport([(200, #"{"content":[{"type":"text","text":\#(escaped)}],"stop_reason":"end_turn"}"#)])
    let a = try await AssessmentRequest.run(input(stats(good: 15)), client: ClaudeClient(apiKey: "k", model: "m", transport: t))
    #expect(a.band == "Merit" && a.suggestedTempo == 80)
    let sys = t.body()["system"] as? String ?? ""
    #expect(sys.contains("Distinction"))
}

@Test func networkFailureFallsBackLocally() async {
    let t = FakeTransport([])
    t.error = URLError(.notConnectedToInternet)
    let out = await AssessmentRequest.runOrFallback(input(stats(good: 19)), client: ClaudeClient(apiKey: "k", model: "m", transport: t))
    #expect(out.usedAI == false)
    #expect(out.error != nil)
    #expect(out.assessment.band == "Distinction")
}

@Test func noKeyFallsBackSilently() async {
    let out = await AssessmentRequest.runOrFallback(input(stats(good: 19)), client: nil)
    #expect(out.usedAI == false && out.error == nil)
}
