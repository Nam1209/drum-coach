import DrumCore

public enum ClickSound: String, Codable, CaseIterable, Sendable {
    case click, beep, woodblock, cowbell, hiHat, rimshot
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
    public static let `default`: [Int: LevelTone] = [
        5: LevelTone(sound: .beep, pitchHz: 1760, gainDb: 0),      // high bell — beat 1 / accent
        4: LevelTone(sound: .click, pitchHz: 1320, gainDb: -2),    // high click — beats 2, 3, 4
        3: LevelTone(sound: .cowbell, pitchHz: 880, gainDb: -5),   // cowbell — "&"
        2: LevelTone(sound: .woodblock, pitchHz: 660, gainDb: -9), // low woodblock — clear "e"/"a"
        1: LevelTone(sound: .hiHat, pitchHz: 0, gainDb: -14),      // soft hi-hat — background "e"/"a"
    ]

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

    /// Seconds per click beat (the time signature's beat unit).
    public var secondsPerBeat: Double { 60.0 / bpm * 4.0 / Double(timeSignature.unit) }
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
        let beatsPerBar = s.timeSignature.beats
        let samplesPerBeat = sampleRate * s.secondsPerBeat

        let slots = max(s.pattern.slots.count, 1)
        forEachTick(spt: samplesPerBeat / Double(slots), from: from, to: to) { n, sample in
            let beat = n / slots, slot = n % slots
            let bar = beat / beatsPerBar, beatInBar = beat % beatsPerBar
            guard s.gap?.isMuted(bar: bar) != true, s.beatSkip.plays(beatInBar: beatInBar) else { return }
            var cell = s.pattern.slots[slot]
            if s.accentBeatOne, beatInBar == 0, slot == 0 { cell.level = 5 }
            guard let tone = ToneLadder.tone(for: cell, ladder: s.ladder) else { return }
            let kind: ClickKind = slot != 0 ? .subdivision : (beatInBar == 0 ? .downbeat : .beat)
            body(ClickEvent(sampleTime: sample, kind: kind, bar: bar, level: cell.level, tone: tone))
        }

        // Spoken counting runs alongside the clicks; it follows the gap but not beat skip.
        let per = voiceLabels.count
        guard per > 0 else { return }
        forEachTick(spt: samplesPerBeat / Double(per), from: from, to: to) { n, sample in
            let beat = n / per, sub = n % per
            let bar = beat / beatsPerBar
            guard s.gap?.isMuted(bar: bar) != true else { return }
            let label = sub == 0 ? numberLabels[min(beat % beatsPerBar, numberLabels.count - 1)] : voiceLabels[sub]
            let tone = LevelTone(sound: .voice, pitchHz: 0, gainDb: sub == 0 ? 0 : -4)
            body(ClickEvent(sampleTime: sample, kind: .voice(label), bar: bar, level: sub == 0 ? 4 : 2, tone: tone))
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
