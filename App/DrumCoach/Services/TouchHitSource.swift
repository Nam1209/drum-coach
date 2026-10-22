import DrumAnalysis
import DrumAudio
import DrumCore
import Foundation

/// Hits from tapping the screen: practise rhythm without a pad or kit (e.g. on the train with headphones).
final class TouchHitSource: HitSource, @unchecked Sendable {
    let hits: AsyncStream<Hit>
    let reportDelay: TimeInterval = 0.03
    private let continuation: AsyncStream<Hit>.Continuation
    private let offset: TimeInterval

    init(calibrationOffset: TimeInterval = 0) {
        (hits, continuation) = AsyncStream.makeStream(of: Hit.self, bufferingPolicy: .bufferingNewest(64))
        offset = calibrationOffset
    }

    func start() throws {}
    func stop() {}

    func tap(_ voice: Voice?) {
        continuation.yield(Hit(time: HostClock.now() - offset, voice: voice, velocity: 0.8))
    }

    deinit { continuation.finish() }
}
