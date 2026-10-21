import AVFoundation
import DrumAnalysis
import Foundation
import os

/// Listens to the microphone and emits a `Hit` for every detected stroke (no drum identity).
public final class MicOnsetSource: HitSource, @unchecked Sendable {
    public let hits: AsyncStream<Hit>
    /// Input taps deliver buffers of up to ~100–400 ms.
    public let reportDelay: TimeInterval = 0.45
    private let continuation: AsyncStream<Hit>.Continuation
    private let engine = AVAudioEngine()
    private let detector = OSAllocatedUnfairLock<(any OnsetDetecting)?>(initialState: nil)
    private let makeDetector: @Sendable (Double) -> any OnsetDetecting
    private let offset: OSAllocatedUnfairLock<TimeInterval>
    /// Peak of the latest input buffer (0…1) and the host time of the latest stroke, for a live level meter.
    private let meter = OSAllocatedUnfairLock<(level: Float, lastHit: TimeInterval)>(initialState: (0, -.infinity))

    /// Loudness the mic hears right now (0…1 peak of the last ~5 ms buffer).
    public var inputLevel: Float { meter.withLock { $0.level } }
    /// Host time of the last detected stroke.
    public var lastHitTime: TimeInterval { meter.withLock { $0.lastHit } }

    /// - Parameters:
    ///   - calibrationOffset: measured extra latency (seconds) subtracted from every hit.
    ///   - threshold: onset threshold (lower = more sensitive).
    public convenience init(calibrationOffset: TimeInterval = 0, threshold: Double = 0.012) {
        self.init(calibrationOffset: calibrationOffset) { OnsetDetector(sampleRate: $0, threshold: threshold) }
    }

    /// Use a custom detector, e.g. `SyllableOnsetDetector` for spoken counting.
    public init(calibrationOffset: TimeInterval = 0, makeDetector: @escaping @Sendable (Double) -> any OnsetDetecting) {
        (hits, continuation) = AsyncStream.makeStream(of: Hit.self, bufferingPolicy: .bufferingNewest(256))
        offset = OSAllocatedUnfairLock(initialState: calibrationOffset)
        self.makeDetector = makeDetector
    }

    public func setCalibrationOffset(_ value: TimeInterval) { offset.withLock { $0 = value } }

    /// Host-time windows (already latency-corrected) in which onsets are ignored, e.g. around each click.
    public func setSuppressWindows(_ windows: [ClosedRange<TimeInterval>]) {
        detector.withLock { $0?.suppressWindows = windows }
    }

    public func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let made = makeDetector(format.sampleRate)
        detector.withLock { $0 = made }
        #if os(iOS)
        let inputLatency = AVAudioSession.sharedInstance().inputLatency
        #else
        let inputLatency = 0.0
        #endif
        let cont = continuation
        input.installTap(onBus: 0, bufferSize: 256, format: format) { [detector, offset, meter] buffer, time in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let frames = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            let level = frames.reduce(Float(0)) { max($0, abs($1)) }
            let host = time.isHostTimeValid ? HostClock.seconds(fromHostTime: time.hostTime) : HostClock.now()
            let start = host - inputLatency - offset.withLock { $0 }
            let onsets = detector.withLock { $0?.process(frames, startTime: start) ?? [] }
            meter.withLock { $0.level = level; if let last = onsets.last { $0.lastHit = last.time } }
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
