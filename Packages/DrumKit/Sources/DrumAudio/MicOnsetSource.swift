import AVFoundation
import DrumAnalysis
import Foundation
import os

/// Listens to the microphone and emits a `Hit` for every detected stroke (no drum identity).
public final class MicOnsetSource: HitSource, @unchecked Sendable {
    public let hits: AsyncStream<Hit>
    private let continuation: AsyncStream<Hit>.Continuation
    private let engine = AVAudioEngine()
    private let detector = OSAllocatedUnfairLock<OnsetDetector?>(initialState: nil)
    private let offset: OSAllocatedUnfairLock<TimeInterval>
    private let sensitivity: Double

    /// - Parameters:
    ///   - calibrationOffset: measured extra latency (seconds) subtracted from every hit.
    ///   - threshold: onset threshold (lower = more sensitive).
    public init(calibrationOffset: TimeInterval = 0, threshold: Double = 0.15) {
        (hits, continuation) = AsyncStream.makeStream(of: Hit.self, bufferingPolicy: .bufferingNewest(256))
        offset = OSAllocatedUnfairLock(initialState: calibrationOffset)
        sensitivity = threshold
    }

    public func setCalibrationOffset(_ value: TimeInterval) { offset.withLock { $0 = value } }

    /// Host-time windows (already latency-corrected) in which onsets are ignored, e.g. around each click.
    public func setSuppressWindows(_ windows: [ClosedRange<TimeInterval>]) {
        detector.withLock { $0?.suppressWindows = windows }
    }

    public func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        detector.withLock { $0 = OnsetDetector(sampleRate: format.sampleRate, threshold: sensitivity) }
        #if os(iOS)
        let inputLatency = AVAudioSession.sharedInstance().inputLatency
        #else
        let inputLatency = 0.0
        #endif
        let cont = continuation
        input.installTap(onBus: 0, bufferSize: 256, format: format) { [detector, offset] buffer, time in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let frames = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            let host = time.isHostTimeValid ? HostClock.seconds(fromHostTime: time.hostTime) : HostClock.now()
            let start = host - inputLatency - offset.withLock { $0 }
            let onsets = detector.withLock { $0?.process(frames, startTime: start) ?? [] }
            for o in onsets { cont.yield(Hit(time: o.time, voice: nil, velocity: o.strength)) }
        }
        try engine.start()
    }

    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    deinit { continuation.finish() }
}
