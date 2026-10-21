import Darwin
import Testing
@testable import DrumAudio

@Test func hostClockMatchesMachTime() {
    let t = HostClock.seconds(fromHostTime: mach_absolute_time())
    #expect(abs(t - HostClock.now()) < 0.01)
}

@Test func hostClockRoundTrip() {
    let s = 1234.5678
    #expect(abs(HostClock.seconds(fromHostTime: HostClock.hostTime(fromSeconds: s)) - s) < 1e-6)
}
