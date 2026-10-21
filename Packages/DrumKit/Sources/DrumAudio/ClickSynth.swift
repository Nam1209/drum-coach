import AVFoundation
import Foundation

/// Synthesizes metronome sounds so the app needs no sample files.
public enum ClickSynth {
    public static func linearGain(db: Double) -> Float { Float(pow(10, db / 20)) }

    /// Every take of a sound at this tuning and output rate. Recorded sounds have several takes so repeated clicks
    /// are not identical (that sameness is what makes a metronome sound fake); synthetic ones have one.
    public static func variants(sound: ClickSound, pitchHz: Double, sampleRate: Double) -> [[Float]] {
        guard let takes = recordings[sound], !takes.isEmpty else { return [render(sound: sound, pitchHz: pitchHz, sampleRate: sampleRate)] }
        let tuning = pitchHz > 0 ? pitchHz / 1_000 : 1
        // Playing a 48 kHz take as if it were recorded at 48 kHz × tuning shifts its pitch by `tuning`.
        return takes.map { CountVoiceBank.resample($0, from: 48_000 * tuning, to: sampleRate) }
    }

    /// The bundled recordings (48 kHz mono), loaded once.
    private static let recordings: [ClickSound: [[Float]]] = [
        .metronome: (1...4).compactMap { load("mechanical-\($0)") },
        .sticks: (1...2).compactMap { load("sticks-\($0)") },
    ]

    private static func load(_ name: String) -> [Float]? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "wav", subdirectory: "Clicks"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil, let channel = buffer.floatChannelData?[0] else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    public static func render(sound: ClickSound, pitchHz: Double, sampleRate: Double) -> [Float] {
        switch sound {
        case .metronome, .sticks:
            variants(sound: sound, pitchHz: pitchHz, sampleRate: sampleRate).first
                ?? tone(1_000, partials: [(1, 1)], decay: 0.01, length: 0.03, sr: sampleRate, noise: 0.3)
        case .click: tone(pitchHz, partials: [(1, 1), (2.7, 0.2)], decay: 0.012, length: 0.03, sr: sampleRate, noise: 0.06)
        case .beep: tone(pitchHz, partials: [(1, 1), (2, 0.3)], decay: 0.05, length: 0.12, sr: sampleRate, noise: 0)
        case .woodblock: wood(pitchHz > 0 ? pitchHz : 900, sr: sampleRate, character: .dry)
        case .cowbell: tone(pitchHz, partials: [(1, 1), (1.48, 0.8)], decay: 0.06, length: 0.2, sr: sampleRate, noise: 0)
        case .rimshot: tone(max(pitchHz, 400), partials: [(1, 0.6), (2.3, 0.4)], decay: 0.015, length: 0.06, sr: sampleRate, noise: 0.6)
        case .hiHat: tone(0, partials: [], decay: 0.02, length: 0.06, sr: sampleRate, noise: 1)
        case .voice: tone(pitchHz > 0 ? pitchHz : 1000, partials: [(1, 1)], decay: 0.01, length: 0.03, sr: sampleRate, noise: 0)
        case .mechanical: mechanical(pitchHz > 0 ? pitchHz : 1_195, sr: sampleRate)
        case .tick: tone(pitchHz > 0 ? pitchHz : 2000, partials: [(1, 0.5), (1.83, 0.2)], decay: 0.0018, length: 0.012,
                         sr: sampleRate, noise: 0.9, attack: 0.0002)
        }
    }

    /// A mechanical wooden metronome, rebuilt from the user's spectral analysis of a reference recording:
    /// a ~1 ms noise transient (300 Hz–10 kHz) that drops 20 dB within ~8 ms, then inharmonic resonances
    /// (main peak 1195 Hz) about 20 dB below it that fade to −40 dB in 85–150 ms. `pitch` moves the whole set.
    static func mechanical(_ pitch: Double, sr: Double) -> [Float] {
        let count = Int(0.16 * sr), scale = pitch / 1_195
        var out = [Double](repeating: 0, count: count)
        let attack = 0.001
        func onset(_ t: Double) -> Double { t < attack ? 0.5 - 0.5 * cos(Double.pi * t / attack) : 1 }

        // Transient: band-limited noise (two high-pass and one low-pass first-order stages).
        var rng = SplitMix(seed: 0x7e1c)
        let hp = exp(-2 * Double.pi * 300 / sr), lp = exp(-2 * Double.pi * 10_000 / sr)
        var hp1 = (x: 0.0, y: 0.0), hp2 = (x: 0.0, y: 0.0), low = 0.0
        for i in 0..<count {
            let t = Double(i) / sr
            let w = (rng.nextUnit() * 2 - 1) * onset(t) * exp(-t / 0.0025)
            let a = hp * (hp1.y + w - hp1.x); hp1 = (w, a)
            let b = hp * (hp2.y + a - hp2.x); hp2 = (a, b)
            low = (1 - lp) * b + lp * low
            out[i] += low * 2.2
        }

        // Resonances: (Hz in the reference, level dB relative to the main peak, decay seconds).
        let modes: [(Double, Double, Double)] = [
            (1_195, 0, 0.037), (1_037, -12, 0.037), (393, -10, 0.065), (3_463, -13, 0.030), (2_695, -16, 0.030),
            (5_268, -18, 0.065), (527, -19, 0.037), (914, -19, 0.037), (3_803, -19, 0.030), (4_113, -19, 0.030),
        ]
        for (k, (hz, level, decay)) in modes.enumerated() {
            let f = hz * scale
            guard f < sr / 2 else { continue }
            let amp = 0.1 * pow(10, level / 20), phase = Double(k) * 1.7
            for i in 0..<count {
                let t = Double(i) / sr
                out[i] += amp * onset(t) * exp(-t / decay) * sin(2 * Double.pi * f * t + phase)
            }
        }
        for i in 0..<count { out[i] *= min(1, Double(count - i) / Double(count) * 10) }   // clean end
        let peak = out.map(abs).max() ?? 0
        return out.map { Float(peak > 0 ? $0 * 0.9 / peak : 0) }
    }

    /// How a wooden block rings: the strike, and its resonant modes as (frequency ratio, decay seconds, level).
    struct WoodCharacter: Sendable {
        var strikeMs: Double
        var click: Double            // unfiltered share of the strike: the hard "knock" at the start
        var modes: [(Double, Double, Double)]
        var length: Double

        /// Hard wood with uneven overtones and a short ring, like a mechanical wooden metronome.
        static let hard = WoodCharacter(strikeMs: 0.4, click: 0.12,
                                        modes: [(1, 0.045, 1), (2.62, 0.022, 0.55), (4.16, 0.010, 0.25), (0.52, 0.030, 0.35)], length: 0.12)
        static let dry = WoodCharacter(strikeMs: 0.3, click: 0.15,
                                       modes: [(1, 0.025, 1), (2.62, 0.012, 0.5), (4.16, 0.006, 0.25), (0.52, 0.018, 0.3)], length: 0.08)
        static let hollow = WoodCharacter(strikeMs: 0.6, click: 0.06,
                                          modes: [(1, 0.070, 1), (2.48, 0.030, 0.4), (3.9, 0.012, 0.15), (0.5, 0.050, 0.55)], length: 0.16)
    }

    /// A struck wooden block: a short strike rings damped resonators (the block's note, uneven overtones and a hollow
    /// body below), like a real wood metronome rather than a sine "beep".
    static func wood(_ f0: Double, sr: Double, character c: WoodCharacter = .hard) -> [Float] {
        let count = Int(c.length * sr)
        var rng = SplitMix(seed: 0x00d)
        let strike = max(1, Int(c.strikeMs / 1000 * sr))
        let excitation: [Double] = (0..<count).map { i in
            guard i < strike else { return 0 }
            return (rng.nextUnit() * 2 - 1) * (0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(strike)))
        }
        var out = excitation.map { $0 * c.click * 8 }
        for (ratio, decay, level) in c.modes where f0 * ratio < sr / 2 {
            let w = 2 * Double.pi * f0 * ratio / sr, r = exp(-1 / (decay * sr))
            let a1 = 2 * r * cos(w), a2 = -r * r
            var y1 = 0.0, y2 = 0.0
            for i in 0..<count {
                let y = excitation[i] * (1 - r) + a1 * y1 + a2 * y2
                out[i] += level * y
                y2 = y1; y1 = y
            }
        }
        for i in 0..<count { out[i] *= min(1, Double(count - i) / Double(count) * 8) }   // clean end
        let peak = out.map(abs).max() ?? 0
        return out.map { Float(peak > 0 ? $0 * 0.9 / peak : 0) }
    }

    /// Sum of decaying sine partials plus optional high-passed noise, normalized to a 0.9 peak.
    private static func tone(_ f0: Double, partials: [(Double, Double)], decay: Double, length: Double,
                             sr: Double, noise: Double, attack attackSeconds: Double = 0.0015) -> [Float] {
        let count = Int(length * sr)
        var out = [Float](repeating: 0, count: count)
        var rng = SplitMix(seed: 0x5eed)
        var lastNoise = 0.0
        // 1.5 ms raised-cosine attack: takes the sting off the onset without blurring where the click is heard.
        let attack = Int(attackSeconds * sr)
        for i in 0..<count {
            let t = Double(i) / sr
            var env = exp(-t / decay)
            if i < attack { env *= 0.5 - 0.5 * cos(Double.pi * Double(i) / Double(max(attack, 1))) }
            let tail = Double(count - i) / Double(count)       // force a clean fade to zero
            env *= min(1, tail * 8)
            var v = 0.0
            for (ratio, amp) in partials { v += amp * sin(2 * .pi * f0 * ratio * t) }
            if noise > 0 {
                let w = rng.nextUnit() * 2 - 1
                v += noise * (w - lastNoise)                     // first-order high-pass for a brighter tick
                lastNoise = w
            }
            out[i] = Float(v * env)
        }
        let peak = out.map(abs).max() ?? 0
        if peak > 0 { let k = 0.9 / peak; for i in out.indices { out[i] *= k } }
        return out
    }
}

/// Deterministic PRNG so renders are reproducible.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
