import AVFoundation
import Foundation
import os

/// Shared between the main actor and the real-time render callback.
final class MetronomeRenderer: @unchecked Sendable {
    struct Shared {
        var schedule: ScheduleState
        var mixer = ClickMixer()
        var cursor: Int64 = 0
        var firstHostTime: TimeInterval?
        var toneCache: [LevelTone: [Float]] = [:]
        var syllableCache: [String: [Float]] = [:]
        var volume: Float = 1
        var voiceVolume: Float = 1
        var lastBar = 0
        var lastBeatSample: Int64 = 0
    }

    let sampleRate: Double
    let state: OSAllocatedUnfairLock<Shared>
    /// Allocated once; render blocks are processed in slices of at most this many frames.
    private var scratch = [Float](repeating: 0, count: 4096)

    init(settings: MetronomeSettings, sampleRate: Double) {
        self.sampleRate = sampleRate
        state = OSAllocatedUnfairLock(initialState: Shared(schedule: ScheduleState(settings: settings, sampleRate: sampleRate)))
    }

    /// Fill `frames` mono samples. Called on the audio thread.
    func render(frames: Int, hostTime: UInt64, into buffer: UnsafeMutablePointer<Float>) {
        var done = 0
        while done < frames {
            let n = min(frames - done, scratch.count)
            renderSlice(frames: n, hostTime: hostTime, into: buffer + done)
            done += n
        }
    }

    private func renderSlice(frames: Int, hostTime: UInt64, into buffer: UnsafeMutablePointer<Float>) {
        for i in 0..<frames { scratch[i] = 0 }
        state.withLock { s in
            if s.firstHostTime == nil { s.firstHostTime = HostClock.seconds(fromHostTime: hostTime) }
            let from = s.cursor, to = s.cursor + Int64(frames)
            s.schedule.forEachEvent(from: from, to: to) { e in
                let offset = Int(e.sampleTime - from)
                switch e.kind {
                case .voice(let label):
                    if let samples = s.syllableCache[label] {
                        s.mixer.trigger(samples: samples, gain: s.voiceVolume * ClickSynth.linearGain(db: e.tone.gainDb), atFrame: offset)
                    }
                default:
                    if let samples = s.toneCache[e.tone] {
                        s.mixer.trigger(samples: samples, gain: s.volume * ClickSynth.linearGain(db: e.tone.gainDb), atFrame: offset)
                    }
                    s.lastBar = e.bar
                    s.lastBeatSample = e.sampleTime
                }
            }
            s.mixer.render(into: &scratch, count: frames)
            s.cursor = to
        }
        for i in 0..<frames { buffer[i] = scratch[i] }
    }
}

/// Plays the metronome with sample-accurate timing through AVAudioEngine.
@MainActor
public final class MetronomeEngine: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var settings: MetronomeSettings

    private let engine = AVAudioEngine()
    private let voiceBank: CountVoiceBank
    private var renderer: MetronomeRenderer?
    private var sourceNode: AVAudioSourceNode?
    private var startLatency: TimeInterval = 0

    public init(voiceBank: CountVoiceBank, settings: MetronomeSettings = MetronomeSettings(bpm: 70)) {
        self.voiceBank = voiceBank
        self.settings = settings
    }

    /// Output latency of the current route, in seconds.
    public var outputLatency: TimeInterval {
        #if os(iOS)
        AVAudioSession.sharedInstance().outputLatency + AVAudioSession.sharedInstance().ioBufferDuration
        #else
        0
        #endif
    }

    /// Host time (seconds) at which beat 0 of the current settings is heard; nil until audio starts.
    public var beatZeroHostTime: TimeInterval? {
        guard let r = renderer else { return nil }
        let latency = startLatency
        return r.state.withLock { s in
            s.firstHostTime.map { $0 + Double(s.schedule.origin) / r.sampleRate + latency }
        }
    }

    public func start(settings: MetronomeSettings) throws {
        stop()
        self.settings = settings
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 48_000
        let r = MetronomeRenderer(settings: settings, sampleRate: sampleRate)
        r.state.withLock { $0.toneCache = Self.renderTones(settings.ladder, sampleRate: sampleRate) }
        refreshSyllables(r, settings: settings)
        setVolumes(r, settings)

        let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let node = AVAudioSourceNode(format: mono) { _, timestamp, frameCount, audioBufferList in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let data = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            r.render(frames: Int(frameCount), hostTime: timestamp.pointee.mHostTime, into: data)
            for extra in abl.dropFirst() {
                extra.mData?.copyMemory(from: data, byteCount: Int(frameCount) * MemoryLayout<Float>.size)
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: mono)
        renderer = r
        sourceNode = node
        startLatency = outputLatency
        try engine.start()
        isRunning = true
    }

    public func stop() {
        guard let node = sourceNode else { return }
        engine.stop()
        engine.detach(node)
        sourceNode = nil
        renderer = nil
        isRunning = false
    }

    /// Change settings while running; tempo/meter changes apply from the next bar line.
    public func update(_ new: MetronomeSettings) {
        let old = settings
        settings = new
        guard let r = renderer else { return }
        if new.ladder != old.ladder {
            let tones = Self.renderTones(new.ladder, sampleRate: r.sampleRate)
            r.state.withLock { $0.toneCache = tones }
        }
        refreshSyllables(r, settings: new)
        setVolumes(r, new)
        r.state.withLock { s in s.schedule.update(new, cursor: s.cursor) }
    }

    private func setVolumes(_ r: MetronomeRenderer, _ s: MetronomeSettings) {
        r.state.withLock { $0.volume = s.volume; $0.voiceVolume = s.voiceVolume }
    }

    private func refreshSyllables(_ r: MetronomeRenderer, settings s: MetronomeSettings) {
        guard let mode = s.voiceCount else { return }
        let per = Counting.labels(mode: mode, beats: 1).count
        let slot = s.secondsPerBeat / Double(per)
        var cache: [String: [Float]] = [:]
        let labels = (1...max(s.timeSignature.beats, 1)).map(String.init) + Counting.labels(mode: mode, beats: 1).dropFirst().map(\.label)
        for label in labels { cache[label] = voiceBank.fitted(label, slot: slot) }
        let fitted = cache
        r.state.withLock { $0.syllableCache = fitted }
    }

    nonisolated static func renderTones(_ ladder: [Int: LevelTone], sampleRate: Double) -> [LevelTone: [Float]] {
        var cache: [LevelTone: [Float]] = [:]
        for tone in ladder.values {
            for sound in ClickSound.allCases where sound != .voice {
                var t = tone
                t.sound = sound
                cache[t] = ClickSynth.render(sound: sound, pitchHz: tone.pitchHz > 0 ? tone.pitchHz : 1000, sampleRate: sampleRate)
            }
        }
        return cache
    }
}

import DrumCore

#if os(iOS)
public enum AudioSessionConfig {
    /// Play + record with a short IO buffer for low latency.
    public static func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
    }

    /// True when sound is coming out of the built-in speaker (the mic will hear the click).
    public static var isUsingSpeaker: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.portType == .builtInSpeaker }
    }
}
#endif
