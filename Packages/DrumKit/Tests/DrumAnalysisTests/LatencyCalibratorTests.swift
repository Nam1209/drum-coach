import Testing
@testable import DrumAnalysis

private let expected = (0..<16).map { Double($0) * 0.75 }

@Test func calibratorMedian() {
    let est = LatencyCalibrator.estimate(expected: expected, detected: expected.map { $0 + 0.042 })
    #expect(est != nil)
    #expect(abs(est! - 0.042) < 0.001)
}

@Test func calibratorIgnoresAMissedClickAndAnExtraHit() {
    var det = expected.map { $0 + 0.03 }
    det.remove(at: 5)
    det.append(4.1)
    #expect(abs(LatencyCalibrator.estimate(expected: expected, detected: det)! - 0.03) < 0.001)
}

@Test func calibratorRejectsNoise() {
    let jitter: [Double] = [0.05, -0.05, 0.04, -0.03, 0.05, -0.05, 0.01, -0.04, 0.05, -0.05, 0.03, -0.02, 0.05, -0.05, 0.04, -0.05]
    #expect(LatencyCalibrator.estimate(expected: expected, detected: zip(expected, jitter).map(+)) == nil)
}

@Test func calibratorNeedsEightPairs() {
    #expect(LatencyCalibrator.estimate(expected: Array(expected.prefix(7)), detected: Array(expected.prefix(7))) == nil)
}

@Test func calibrationRunExpectedTimes() {
    let run = CalibrationRun(bpm: 80, countInBeats: 4, clicks: 16)
    let e = run.expected(beatZero: 100)
    #expect(e.count == 16)
    #expect(e.first == 100 + 4 * 0.75)
    #expect(abs(e.last! - (100 + 19 * 0.75)) < 1e-9)
    #expect(abs(run.duration - 20 * 0.75) < 1e-9)
}

@Test func calibrationAnalysisSaysHowManyClicksMatchedAndHowEven() {
    // 12 of 16 clicks hit ~40 ms late, 4 count-in taps and 2 stray hits far from any click.
    let steady = expected.prefix(12).map { $0 + 0.04 }
    let countIn = [-3.0, -2.25, -1.5, -0.75]
    let a = LatencyCalibrator.analyze(expected: expected, detected: countIn + steady + [9.4, 10.1])
    #expect(a.clicks == 16)
    #expect(a.matched == 12)
    #expect(a.unmatched == 6)
    #expect(abs(a.medianMs! - 40) < 0.5)
    #expect(a.spreadMs! < 1)
    #expect(a.problem == nil)
    #expect(abs(a.estimate! - 0.04) < 0.001)
}

@Test func calibrationAnalysisNamesTheProblem() {
    let few = LatencyCalibrator.analyze(expected: expected, detected: expected.prefix(5).map { $0 + 0.2 } + expected.prefix(5))
    #expect(few.matched == 5)
    #expect(few.problem == .tooFewMatched)
    #expect(few.estimate == nil)

    let jitter: [Double] = [0.05, -0.05, 0.04, -0.03, 0.05, -0.05, 0.01, -0.04, 0.05, -0.05, 0.03, -0.02, 0.05, -0.05, 0.04, -0.05]
    let uneven = LatencyCalibrator.analyze(expected: expected, detected: zip(expected, jitter).map(+))
    #expect(uneven.matched == 16)
    #expect(uneven.problem == .tooUneven)
    #expect(uneven.spreadMs! > LatencyCalibrator.maxSpread * 1000)
    #expect(uneven.estimate == nil)
}
