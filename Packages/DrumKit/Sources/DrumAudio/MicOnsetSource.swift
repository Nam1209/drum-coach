import AVFoundation
import DrumAnalysis
import DrumCore
import Foundation
import os

/// Listens to the microphone and emits a `Hit` for every detected stroke (no drum identity).
public final class MicOnsetSource: HitSource, @unchecked Sendable {
    public let hits: AsyncStream<Hit>
    /// The real-time sink delivers a few milliseconds at a time, so strokes are reported almost at once.
    public let reportDelay: TimeInterval = 0.08
    private let continuation: AsyncStream<Hit>.Continuation
    /// Detector decisions, carried off the audio thread to be printed (only with `-debugLog`).
    private let diagnostics: AsyncStream<OnsetDiagnostic>
    private let diagnosticsContinuation: AsyncStream<OnsetDiagnostic>.Continuation
    private var logTask: Task<Void, Never>?
    private let engine = AVAudioEngine()
    private var sink: AVAudioSinkNode?
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
        (diagnostics, diagnosticsContinuation) = AsyncStream.makeStream(of: OnsetDiagnostic.self, bufferingPolicy: .bufferingNewest(256))
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
        // A sink node gets the mic on the real-time thread in IO-buffer-sized slices (~5 ms). An input tap would
        // batch ~100 ms or more, so hits would light up late and the run would feel unresponsive.
        if DebugLog.enabled, logTask == nil {
            DebugLog.line("MIC start: sample rate \(Int(format.sampleRate)) Hz, input latency \(Int(inputLatency * 1000)) ms, calibration \(Int(offset.withLock { $0 } * 1000)) ms")
            let stream = diagnostics
            logTask = Task.detached {
                for await d in stream {
                    DebugLog.line(String(format: "MIC %@ at %.3f peak %.2f%% need %.2f%%", d.verdict.rawValue, d.time, d.peak * 100, d.level * 100))
                }
            }
        }
        let node = Self.makeSink(detector: detector, offset: offset, meter: meter, continuation: continuation,
                                 diagnostics: DebugLog.enabled ? diagnosticsContinuation : nil, inputLatency: inputLatency)
        engine.attach(node)
        engine.connect(input, to: node, format: format)
        sink = node
        try engine.start()
    }

    /// Built outside any actor: it runs on the audio thread.
    private static func makeSink(detector: OSAllocatedUnfairLock<(any OnsetDetecting)?>, offset: OSAllocatedUnfairLock<TimeInterval>,
                                 meter: OSAllocatedUnfairLock<(level: Float, lastHit: TimeInterval)>,
                                 continuation cont: AsyncStream<Hit>.Continuation,
                                 diagnostics diag: AsyncStream<OnsetDiagnostic>.Continuation?, inputLatency: TimeInterval) -> AVAudioSinkNode {
        AVAudioSinkNode { timestamp, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
            guard let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let frames = Array(UnsafeBufferPointer(start: data, count: Int(frameCount)))
            let level = frames.reduce(Float(0)) { max($0, abs($1)) }
            let stamp = timestamp.pointee
            let host = stamp.mFlags.contains(.hostTimeValid) ? HostClock.seconds(fromHostTime: stamp.mHostTime) : HostClock.now()
            let start = host - inputLatency - offset.withLock { $0 }
            let onsets = detector.withLock { $0?.process(frames, startTime: start) ?? [] }
            if let diag { for d in detector.withLock({ $0?.drainDiagnostics() ?? [] }) { diag.yield(d) } }
            meter.withLock { $0.level = level; if let last = onsets.last { $0.lastHit = last.time } }
            for o in onsets { cont.yield(Hit(time: o.time, voice: nil, velocity: o.strength)) }
            return noErr
        }
    }

    public func stop() {
        engine.stop()
        if let sink { engine.detach(sink) }
        sink = nil
    }

    deinit {
        continuation.finish()
        diagnosticsContinuation.finish()
        logTask?.cancel()
    }
}
