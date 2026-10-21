import DrumCore
import Foundation

/// One detected stroke on the shared host-time clock.
public struct Hit: Sendable, Hashable {
    /// Host time in seconds, already corrected for input latency and calibration.
    public let time: TimeInterval
    /// Which drum, when known (MIDI); nil for the microphone.
    public let voice: Voice?
    /// 0…1 (MIDI velocity / 127, or the onset strength for the microphone).
    public let velocity: Double

    public init(time: TimeInterval, voice: Voice?, velocity: Double) {
        self.time = time
        self.voice = voice
        self.velocity = velocity
    }
}

public protocol HitSource: AnyObject, Sendable {
    var hits: AsyncStream<Hit> { get }
    func start() throws
    func stop()
}
