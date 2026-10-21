import AVFoundation
import DrumAnalysis
import Foundation
import os

/// Listens to the mic while the player taps the pad 8 times and builds a `PadProfile`.
public final class PadProfileRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let state = OSAllocatedUnfairLock<(profiler: PadProfiler?, level: Float)>(initialState: (nil, 0))

    public init() {}

    /// Taps heard so far (0…8).
    public var hits: Int { state.withLock { $0.profiler?.hits ?? 0 } }
    /// The finished profile, once 8 taps were heard.
    public var profile: PadProfile? { state.withLock { $0.profiler?.profile } }
    /// Loudness the mic hears right now (0…1).
    public var inputLevel: Float { state.withLock { $0.level } }

    public func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        state.withLock { $0.profiler = PadProfiler(sampleRate: format.sampleRate) }
        input.installTap(onBus: 0, bufferSize: 512, format: format, block: Self.tap(state))
        try engine.start()
    }

    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Runs on the audio thread; built outside any actor (see MetronomeEngine.makeSourceNode).
    private static func tap(_ state: OSAllocatedUnfairLock<(profiler: PadProfiler?, level: Float)>) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let frames = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            let level = frames.reduce(Float(0)) { max($0, abs($1)) }
            state.withLock { $0.profiler?.process(frames); $0.level = level }
        }
    }
}

#if os(iOS)
public extension AudioSessionConfig {
    /// A name for the current output (speaker, wired or USB headphones, AirPods…), so latency can be kept per device.
    static var outputName: String {
        AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "Speaker"
    }

    /// Bluetooth headphones add 100–300 ms that changes from moment to moment: timing can't be judged reliably.
    static var isUsingBluetooth: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP].contains($0.portType)
        }
    }
}
#endif
