import Testing
@testable import DrumAnalysis

private func run(_ f: (Double) -> Double, count: Int = 60, spacing: Double = 0.5) -> [(time: Double, offsetMs: Double)] {
    (0..<count).map { i in (Double(i) * spacing, f(Double(i))) }
}

@Test func steadyOffsetPointsToCalibration() {
    let d = TimingDiagnosis(samples: run { i in -32 + (i.truncatingRemainder(dividingBy: 3) - 1) * 3 })
    #expect(d.kind == .constantOffset)
    #expect(abs(d.meanMs + 32) < 1)
}

@Test func growingLateIsDragging() {
    let d = TimingDiagnosis(samples: run { i in i * 1.0 })   // +1 ms per note, 2 notes/s → +120 ms/min
    #expect(d.kind == .dragging)
    #expect(d.driftMsPerMinute > 100)
}

@Test func growingEarlyIsRushing() {
    #expect(TimingDiagnosis(samples: run { i in -i * 0.8 }).kind == .rushing)
}

@Test func tightPlayingIsSteady() {
    #expect(TimingDiagnosis(samples: run { i in (i.truncatingRemainder(dividingBy: 2) - 0.5) * 6 }).kind == .steady)
}

@Test func scatteredPlayingIsUneven() {
    #expect(TimingDiagnosis(samples: run { i in [25, -30, 18, -22, 35, -28][Int(i) % 6] }).kind == .uneven)
}

@Test func tooFewNotesGivesNoVerdict() {
    #expect(TimingDiagnosis(samples: run({ _ in 40 }, count: 5)).kind == .notEnoughData)
}
