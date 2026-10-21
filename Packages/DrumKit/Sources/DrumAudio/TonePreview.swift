import AVFoundation

/// Plays a single metronome tone for auditioning levels in the tone-ladder editor.
@MainActor
public final class TonePreview {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    public func play(_ tone: LevelTone, volume: Float = 1) {
        let samples = ClickSynth.render(sound: tone.sound == .voice ? .click : tone.sound,
                                        pitchHz: tone.pitchHz > 0 ? tone.pitchHz : 1000, sampleRate: 48_000)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let gain = volume * ClickSynth.linearGain(db: tone.gainDb)
        for i in samples.indices { buffer.floatChannelData![0][i] = samples[i] * gain }
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }
}
