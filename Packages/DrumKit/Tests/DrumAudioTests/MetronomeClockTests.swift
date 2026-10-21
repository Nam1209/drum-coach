import DrumCore
import Testing
@testable import DrumAudio

@Test func beatZeroFollowsTheLatestRenderTimestamp() {
    // The sound card runs 0.01% slow against the host clock: after 1 000 s of audio, 1 000.1 s of host time passed.
    let r = MetronomeRenderer(settings: MetronomeSettings(bpm: 60), sampleRate: 48_000)
    var buffer = [Float](repeating: 0, count: 512)
    let start = 100.0
    buffer.withUnsafeMutableBufferPointer { r.render(frames: 512, hostTime: HostClock.hostTime(fromSeconds: start), into: $0.baseAddress!) }
    #expect(abs(r.beatZeroHostTime(latency: 0)! - start) < 1e-6)

    // Pretend 48 000 000 samples (1 000 s) have been rendered, then a callback arrives at host time start + 1000.1.
    r.state.withLock { $0.cursor = 48_000_000 }
    buffer.withUnsafeMutableBufferPointer { r.render(frames: 512, hostTime: HostClock.hostTime(fromSeconds: start + 1000.1), into: $0.baseAddress!) }
    // Beat 1000 is heard now, so beat 0 was effectively at start + 0.1 on the host clock.
    #expect(abs(r.beatZeroHostTime(latency: 0)! - (start + 0.1)) < 1e-6)
}

@Test func beatPositionUsesTheRunningSchedule() {
    let r = MetronomeRenderer(settings: MetronomeSettings(bpm: 60), sampleRate: 48_000)
    var buffer = [Float](repeating: 0, count: 512)
    buffer.withUnsafeMutableBufferPointer { r.render(frames: 512, hostTime: HostClock.hostTime(fromSeconds: 10), into: $0.baseAddress!) }
    #expect(abs(r.beat(atHostTime: 12.5, latency: 0)! - 2.5) < 1e-6)
    #expect(r.beat(atHostTime: 9, latency: 0) == nil)
}
