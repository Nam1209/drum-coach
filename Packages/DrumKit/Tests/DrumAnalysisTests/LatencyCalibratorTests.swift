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
