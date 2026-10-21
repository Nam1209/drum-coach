import Testing
@testable import DrumAudio

@Test func rateFollowsTempo() {
    #expect(BackingTrackPlan.rate(targetBpm: 90, originalBpm: 120) == 0.75)
    #expect(BackingTrackPlan.rate(targetBpm: 120, originalBpm: 0) == 1)
}

@Test func loopFrames() throws {
    let l = try BackingTrackPlan.loop(a: 1.5, b: 3.0, sampleRate: 44_100, length: 10)
    #expect(l.start == 66_150 && l.count == 66_150)
}

@Test func loopRejectsBadRange() {
    #expect(throws: BackingTrackPlan.LoopError.badRange) { try BackingTrackPlan.loop(a: 3, b: 3, sampleRate: 44_100, length: 10) }
    #expect(throws: BackingTrackPlan.LoopError.badRange) { try BackingTrackPlan.loop(a: 2, b: 12, sampleRate: 44_100, length: 10) }
}
