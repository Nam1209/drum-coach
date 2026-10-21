import DrumCore

public enum ClickSound: String, Codable, CaseIterable, Sendable {
    case click, beep, woodblock, cowbell, hiHat, rimshot
    /// A clock's tick: a few milliseconds of bright transient, no ringing pitch.
    case tick
    /// Speaks the counting syllable ("1", "e", "&", "a") at this slot.
    case voice
}

public struct ClickSlot: Codable, Sendable, Equatable {
    /// 0 = off, 1…5 = the five stacked boxes.
    public var level: Int
    /// nil = use the level's default sound from the tone ladder.
    public var sound: ClickSound?

    public init(level: Int, sound: ClickSound? = nil) {
        self.level = level
        self.sound = sound
    }
}

/// Each level has its own sound, pitch and loudness so 1 / e / & / a are distinguishable by ear.
public struct LevelTone: Codable, Sendable, Equatable, Hashable {
    public var sound: ClickSound
    public var pitchHz: Double
    public var gainDb: Double

    public init(sound: ClickSound, pitchHz: Double, gainDb: Double) {
        self.sound = sound
        self.pitchHz = pitchHz
        self.gainDb = gainDb
    }
}

public enum ToneLadder {
    /// A clock's tick-tock: a deeper "tock" on beat 1, light "ticks" elsewhere; nothing rings, so it stays easy on the ears.
    public static let `default`: [Int: LevelTone] = [
        5: LevelTone(sound: .tick, pitchHz: 1300, gainDb: -2),     // tock — beat 1 / accent
        4: LevelTone(sound: .tick, pitchHz: 2000, gainDb: -6),     // tick — beats 2, 3, 4
        3: LevelTone(sound: .tick, pitchHz: 2600, gainDb: -11),    // lighter tick — "&"
        2: LevelTone(sound: .tick, pitchHz: 3200, gainDb: -15),    // faint tick — clear "e"/"a"
        1: LevelTone(sound: .hiHat, pitchHz: 0, gainDb: -20),      // whisper — background "e"/"a"
    ]

    /// The second factory ladder (wooden blocks), recognised in saved settings like the first.
    public static let woodblockDefault: [Int: LevelTone] = [
        5: LevelTone(sound: .woodblock, pitchHz: 880, gainDb: 0),
        4: LevelTone(sound: .woodblock, pitchHz: 660, gainDb: -3),
        3: LevelTone(sound: .click, pitchHz: 520, gainDb: -7),
        2: LevelTone(sound: .woodblock, pitchHz: 440, gainDb: -11),
        1: LevelTone(sound: .hiHat, pitchHz: 0, gainDb: -17),
    ]

    /// The first factory ladder (piercing 1760/1320 Hz beeps), kept to recognise it in saved settings.
    public static let legacyDefault: [Int: LevelTone] = [
        5: LevelTone(sound: .beep, pitchHz: 1760, gainDb: 0),
        4: LevelTone(sound: .click, pitchHz: 1320, gainDb: -2),
        3: LevelTone(sound: .cowbell, pitchHz: 880, gainDb: -5),
        2: LevelTone(sound: .woodblock, pitchHz: 660, gainDb: -9),
        1: LevelTone(sound: .hiHat, pitchHz: 0, gainDb: -14),
    ]

    /// Saved settings still on the old factory ladder move to the new one; a ladder the user edited is kept.
    public static func upgraded(_ ladder: [Int: LevelTone]) -> [Int: LevelTone] {
        ladder == legacyDefault || ladder == woodblockDefault ? `default` : ladder
    }

    public static func tone(for slot: ClickSlot, ladder: [Int: LevelTone] = ToneLadder.default) -> LevelTone? {
        guard slot.level > 0, var tone = ladder[min(slot.level, 5)] else { return nil }
        if let override = slot.sound { tone.sound = override }
        return tone
    }
}

public struct ClickPattern: Codable, Sendable, Equatable {
    /// One beat is divided into `slots.count` equal parts.
    public var slots: [ClickSlot]

    public init(levels: [Int]) { slots = levels.map { ClickSlot(level: $0) } }

    public static let quarter = ClickPattern(levels: [4])
    public static let eighths = ClickPattern(levels: [4, 0, 3, 0])
    public static let sixteenths = ClickPattern(levels: [4, 1, 3, 1])
    public static let triplets = ClickPattern(levels: [4, 2, 2])
    public static let offbeat = ClickPattern(levels: [0, 0, 4, 0])
}

public enum BeatSkip: String, Codable, CaseIterable, Sendable {
    case all, oneOnOneOff, beatOneOnly, backbeat

    func plays(beatInBar b: Int) -> Bool {
        switch self {
        case .all: true
        case .oneOnOneOff: b % 2 == 0
        case .beatOneOnly: b == 0
        case .backbeat: b % 2 == 1
        }
    }
}

public struct GapPattern: Codable, Sendable, Equatable {
    public var playBars: Int
    public var muteBars: Int

    public init(playBars: Int, muteBars: Int) {
        self.playBars = playBars
        self.muteBars = muteBars
    }

    func isMuted(bar: Int) -> Bool {
        let cycle = playBars + muteBars
        guard cycle > 0, muteBars > 0 else { return false }
        return bar % cycle >= playBars
    }
}

public struct MetronomeSettings: Sendable, Codable, Equatable {
    /// Quarter-note tempo. In x/8 meters each click beat is an eighth note.
    public var bpm: Double
    public var timeSignature: TimeSignature
    public var pattern: ClickPattern
    public var accentBeatOne: Bool
    public var beatSkip: BeatSkip
    public var voiceCount: CountMode?
    public var gap: GapPattern?
    public var ladder: [Int: LevelTone]
    public var volume: Float
    public var voiceVolume: Float
    public var musicVolume: Float
    /// 0.5 = straight; up to 0.75. Moves the off-beat 8th click (and the spoken "&").
    public var swing: Double = Swing.straight
    /// Bars at the start whose beats are spoken "1 2 3 4" even when counting is off (the count-in). Not saved.
    public var spokenCountInBars = 0

    public init(bpm: Double, timeSignature: TimeSignature = TimeSignature(beats: 4, unit: 4),
                pattern: ClickPattern = .quarter, accentBeatOne: Bool = false, beatSkip: BeatSkip = .all,
                voiceCount: CountMode? = nil, gap: GapPattern? = nil, ladder: [Int: LevelTone] = ToneLadder.default,
                volume: Float = 1, voiceVolume: Float = 1, musicVolume: Float = 0.25) {
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.pattern = pattern
        self.accentBeatOne = accentBeatOne
        self.beatSkip = beatSkip
        self.voiceCount = voiceCount
        self.gap = gap
        self.ladder = ladder
        self.volume = volume
        self.voiceVolume = voiceVolume
        self.musicVolume = musicVolume
    }

    enum CodingKeys: String, CodingKey {
        case bpm, timeSignature, pattern, accentBeatOne, beatSkip, voiceCount, gap, ladder, volume, voiceVolume, musicVolume, swing
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bpm = try c.decode(Double.self, forKey: .bpm)
        timeSignature = try c.decode(TimeSignature.self, forKey: .timeSignature)
        pattern = try c.decode(ClickPattern.self, forKey: .pattern)
        accentBeatOne = try c.decode(Bool.self, forKey: .accentBeatOne)
        beatSkip = try c.decode(BeatSkip.self, forKey: .beatSkip)
        voiceCount = try c.decodeIfPresent(CountMode.self, forKey: .voiceCount)
        gap = try c.decodeIfPresent(GapPattern.self, forKey: .gap)
        ladder = try c.decode([Int: LevelTone].self, forKey: .ladder)
        volume = try c.decode(Float.self, forKey: .volume)
        voiceVolume = try c.decode(Float.self, forKey: .voiceVolume)
        musicVolume = try c.decode(Float.self, forKey: .musicVolume)
        swing = try c.decodeIfPresent(Double.self, forKey: .swing) ?? Swing.straight
    }

    /// Settings saved by the first release with its untouched factory sound (busy 8th clicks, piercing beeps) become
    /// the gentle default: one wooden "tick" on beat 1 and the same soft "tock" on the other beats.
    public func upgradedFromFirstRelease() -> MetronomeSettings {
        guard ladder == ToneLadder.legacyDefault || ladder == ToneLadder.woodblockDefault else { return self }
        var s = self
        s.ladder = ToneLadder.default
        if pattern == .eighths { s.pattern = .quarter }
        return s
    }

    /// Seconds per click beat (the time signature's beat unit).
    /// Length of one counted beat (`bpm` is always quarter notes per minute); in compound meters a beat is a dotted quarter.
    public var secondsPerBeat: Double { 60.0 / bpm * 4.0 / Double(timeSignature.unit) * (timeSignature.isCompound ? 3 : 1) }
    /// Counted beats per bar: 4 in 4/4, 7 in 7/8, but 4 in 12/8.
    public var beatsPerBar: Int { timeSignature.isCompound ? timeSignature.beats / 3 : timeSignature.beats }
}

public enum ClickKind: Sendable, Hashable {
    case downbeat, beat, subdivision
    case voice(String)
}

public struct ClickEvent: Sendable, Hashable {
    public let sampleTime: Int64
    public let kind: ClickKind
    public let bar: Int
    public let level: Int
    public let tone: LevelTone
}

public enum ClickSchedule {
    /// All events with `from <= sampleTime < to`, sorted. Sample of tick n is round(n × samplesPerTick), so error never accumulates.
    public static func events(settings s: MetronomeSettings, sampleRate: Double, from: Int64, to: Int64) -> [ClickEvent] {
        var out: [ClickEvent] = []
        forEachEvent(settings: s, voiceLabels: voiceLabels(for: s), sampleRate: sampleRate, from: from, to: to) { out.append($0) }
        out.sort { $0.sampleTime < $1.sampleTime }
        return out
    }

    /// Syllables of one beat for the spoken count ("", "e", "&", "a"); computed off the audio thread.
    static func voiceLabels(for s: MetronomeSettings) -> [String] {
        s.voiceCount.map { Counting.labels(mode: $0, beats: 1).map(\.label) } ?? []
    }

    /// Visits every event in the window without building arrays (safe for the real-time render thread).
    /// Clicks and spoken syllables are visited in two passes, so the order is not chronological.
    static func forEachEvent(settings s: MetronomeSettings, voiceLabels: [String], sampleRate: Double,
                             from: Int64, to: Int64, _ body: (ClickEvent) -> Void) {
        guard to > from, s.bpm > 0 else { return }
        let beatsPerBar = s.beatsPerBar
        let samplesPerBeat = sampleRate * s.secondsPerBeat

        // Swing only makes sense for 8th notes in a quarter-note meter: it delays the "&" (slot 2 of 2).
        let swing = s.timeSignature.unit == 4 && s.swing > Swing.straight ? min(0.75, s.swing) : Swing.straight
        // A swung "&" sounds later than its straight tick, so look back far enough to catch ticks from the previous window.
        let lookback = swing > Swing.straight ? Int64((samplesPerBeat * (swing - 0.5)).rounded(.up)) + 1 : 0

        let slots = max(s.pattern.slots.count, 1)
        // 8th-note content: only the beat and the middle slot sound (the "e"/"a" slots of a finer grid are silent).
        let half = slots / 2
        var eighthsOnly = slots % 2 == 0
        for (i, c) in s.pattern.slots.enumerated() where half > 0 && i % half != 0 && c.level != 0 { eighthsOnly = false }
        forEachTick(spt: samplesPerBeat / Double(slots), from: from - lookback, to: to) { n, sample in
            let beat = n / slots, slot = n % slots
            let bar = beat / beatsPerBar, beatInBar = beat % beatsPerBar
            guard s.gap?.isMuted(bar: bar) != true, s.beatSkip.plays(beatInBar: beatInBar) else { return }
            var cell = s.pattern.slots[slot]
            if s.accentBeatOne, beatInBar == 0, slot == 0 { cell.level = 5 }
            guard let tone = ToneLadder.tone(for: cell, ladder: s.ladder) else { return }
            let kind: ClickKind = slot != 0 ? .subdivision : (beatInBar == 0 ? .downbeat : .beat)
            let at = swing > Swing.straight && eighthsOnly && slot == half
                ? Int64(((Double(beat) + swing) * samplesPerBeat).rounded()) : sample
            guard at >= from, at < to else { return }
            body(ClickEvent(sampleTime: at, kind: kind, bar: bar, level: cell.level, tone: tone))
        }

        // Spoken counting runs alongside the clicks; it follows the gap but not beat skip.
        let per = voiceLabels.count
        if per == 0, s.spokenCountInBars > 0 {
            // Counting is off: still say the beat numbers of the count-in so the player knows when to come in.
            forEachTick(spt: samplesPerBeat, from: from, to: min(to, Int64((Double(s.spokenCountInBars * beatsPerBar) * samplesPerBeat).rounded()))) { n, sample in
                body(ClickEvent(sampleTime: sample, kind: .voice(numberLabels[min(n % beatsPerBar, numberLabels.count - 1)]),
                                bar: n / beatsPerBar, level: 4, tone: LevelTone(sound: .voice, pitchHz: 0, gainDb: 0)))
            }
        }
        guard per > 0 else { return }
        forEachTick(spt: samplesPerBeat / Double(per), from: from - lookback, to: to) { n, sample in
            let beat = n / per, sub = n % per
            let bar = beat / beatsPerBar
            guard s.gap?.isMuted(bar: bar) != true else { return }
            let label = sub == 0 ? numberLabels[min(beat % beatsPerBar, numberLabels.count - 1)] : voiceLabels[sub]
            let tone = LevelTone(sound: .voice, pitchHz: 0, gainDb: sub == 0 ? 0 : -4)
            let at = swing > Swing.straight && per == 2 && sub == 1
                ? Int64(((Double(beat) + swing) * samplesPerBeat).rounded()) : sample
            guard at >= from, at < to else { return }
            body(ClickEvent(sampleTime: at, kind: .voice(label), bar: bar, level: sub == 0 ? 4 : 2, tone: tone))
        }
    }

    /// Beat numbers as preallocated strings (no string interpolation on the audio thread).
    static let numberLabels = (1...32).map(String.init)

    private static func forEachTick(spt: Double, from: Int64, to: Int64, _ body: (Int, Int64) -> Void) {
        var n = max(0, Int((Double(from) / spt).rounded(.down)) - 1)
        while true {
            let sample = Int64((Double(n) * spt).rounded())
            if sample >= to { break }
            if sample >= from { body(n, sample) }
            n += 1
        }
    }
}
