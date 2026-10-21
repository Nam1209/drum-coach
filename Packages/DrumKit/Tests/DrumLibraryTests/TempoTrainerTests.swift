import Testing
@testable import DrumLibrary

@Test func rampSteps() {
    var t = TempoTrainer(TempoRamp(start: 60, target: 80, step: 5, everyBars: 2, requireAccuracy: nil))
    #expect(t.currentBpm == 60)
    #expect(t.barCompleted(accuracy: nil) == 60)
    #expect(t.barCompleted(accuracy: nil) == 65)
    for _ in 0..<6 { _ = t.barCompleted(accuracy: nil) }
    #expect(t.currentBpm == 80)
    for _ in 0..<12 { _ = t.barCompleted(accuracy: nil) }
    #expect(t.currentBpm == 80)
}

@Test func holdsTempoWhenNotAccurate() {
    var t = TempoTrainer(TempoRamp(start: 60, target: 80, step: 5, everyBars: 2, requireAccuracy: 0.9))
    _ = t.barCompleted(accuracy: 0.8)
    #expect(t.barCompleted(accuracy: 0.8) == 60)
    _ = t.barCompleted(accuracy: 0.95)
    #expect(t.barCompleted(accuracy: 0.95) == 65)
}

@Test func accuracyIsAveragedOverTheStep() {
    var t = TempoTrainer(TempoRamp(start: 60, target: 80, step: 5, everyBars: 2, requireAccuracy: 0.9))
    _ = t.barCompleted(accuracy: 1.0)
    #expect(t.barCompleted(accuracy: 0.7) == 60)   // mean 0.85 < 0.9
}

@Test func defaultRampMatchesUserRange() {
    #expect(TempoRamp.default == TempoRamp(start: 50, target: 90, step: 2, everyBars: 4, requireAccuracy: 0.9))
}

@Test func rampDownwardIsClamped() {
    var t = TempoTrainer(TempoRamp(start: 90, target: 80, step: 4, everyBars: 1, requireAccuracy: nil))
    #expect(t.barCompleted(accuracy: nil) == 86)
    #expect(t.barCompleted(accuracy: nil) == 82)
    #expect(t.barCompleted(accuracy: nil) == 80)
}
