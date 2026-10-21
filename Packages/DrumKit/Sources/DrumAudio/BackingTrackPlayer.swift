import AVFoundation
import Foundation

public enum BackingTrackPlan {
    public enum LoopError: Error, Equatable { case badRange }

    /// Playback rate that turns `originalBpm` into `targetBpm` (pitch is kept by AVAudioUnitTimePitch).
    public static func rate(targetBpm: Double, originalBpm: Double) -> Float {
        guard originalBpm > 0, targetBpm > 0 else { return 1 }
        return Float(targetBpm / originalBpm)
    }

    /// A–B loop in sample frames; A must be before B and both inside the track.
    public static func loop(a: TimeInterval, b: TimeInterval, sampleRate: Double, length: TimeInterval) throws(LoopError) -> (start: AVAudioFramePosition, count: AVAudioFrameCount) {
        guard a >= 0, b > a, b <= length else { throw .badRange }
        let start = AVAudioFramePosition((a * sampleRate).rounded())
        return (start, AVAudioFrameCount(((b - a) * sampleRate).rounded()))
    }
}

/// Plays an imported song or backing track at a chosen tempo with an optional A–B loop.
@MainActor
public final class BackingTrackPlayer: ObservableObject {
    @Published public private(set) var isPlaying = false
    @Published public private(set) var duration: TimeInterval = 0
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private var file: AVAudioFile?

    public init() {
        engine.attach(player)
        engine.attach(pitch)
        engine.connect(player, to: pitch, format: nil)
        engine.connect(pitch, to: engine.mainMixerNode, format: nil)
    }

    public func load(_ url: URL) throws {
        stop()
        let f = try AVAudioFile(forReading: url)
        file = f
        duration = Double(f.length) / f.processingFormat.sampleRate
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: pitch, format: f.processingFormat)
    }

    public func play(rate: Float, loopA: TimeInterval?, loopB: TimeInterval?, volume: Float) throws {
        guard let file else { return }
        stop()
        pitch.rate = max(0.25, min(2, rate))
        player.volume = volume
        if !engine.isRunning { try engine.start() }
        if let a = loopA, let b = loopB {
            let l = try BackingTrackPlan.loop(a: a, b: b, sampleRate: file.processingFormat.sampleRate, length: duration)
            guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: l.count) else { return }
            file.framePosition = l.start
            try file.read(into: buf, frameCount: l.count)
            player.scheduleBuffer(buf, at: nil, options: .loops)
        } else {
            player.scheduleFile(file, at: nil)
        }
        player.play()
        isPlaying = true
    }

    public func stop() {
        player.stop()
        isPlaying = false
    }
}
