import Testing
import DrumCore
@testable import DrumAudio

private let sr = 48_000.0

@Test func quartersAt120() {
    let e = ClickSchedule.events(settings: MetronomeSettings(bpm: 120, pattern: .quarter), sampleRate: sr, from: 0, to: 96_000)
    #expect(e.map(\.sampleTime) == [0, 24_000, 48_000, 72_000])
    #expect(e[0].kind == .downbeat)
    #expect(e[1].kind == .beat)
}

@Test func noDriftAfterTenMinutes() {
    let e = ClickSchedule.events(settings: MetronomeSettings(bpm: 137, pattern: .sixteenths), sampleRate: sr, from: 0, to: 48_000 * 600)
    let expectedLast = Int64((Double(e.count - 1) * 48_000 * 60 / 137 / 4).rounded())
    #expect(e.last!.sampleTime == expectedLast)
}

@Test func extremes() {
    #expect(!ClickSchedule.events(settings: MetronomeSettings(bpm: 40, pattern: .quarter), sampleRate: sr, from: 0, to: 48_000).isEmpty)
    #expect(ClickSchedule.events(settings: MetronomeSettings(bpm: 300, pattern: .sixteenths), sampleRate: sr, from: 0, to: 48_000).count == 20)
}

@Test func windowBoundariesNoDupes() {
    let s = MetronomeSettings(bpm: 133, pattern: .sixteenths, voiceCount: .sixteenths)
    let whole = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 200_000)
    var pieces: [ClickEvent] = []
    var t: Int64 = 0
    while t < 200_000 {
        pieces += ClickSchedule.events(settings: s, sampleRate: sr, from: t, to: min(t + 256, 200_000))
        t += 256
    }
    #expect(pieces == whole)
}

@Test func gapMutesBars() {
    let s = MetronomeSettings(bpm: 60, pattern: .quarter, gap: GapPattern(playBars: 1, muteBars: 1))
    let e = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000 * 12)
    #expect(Set(e.map(\.bar)) == [0, 2])
}

@Test func backbeatOnly() {
    let s = MetronomeSettings(bpm: 60, pattern: .quarter, beatSkip: .backbeat)
    let e = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000 * 4)
    #expect(e.map(\.sampleTime) == [48_000, 144_000])
}

@Test func beatSkipOneOnOneOff() {
    let s = MetronomeSettings(bpm: 60, pattern: .quarter, beatSkip: .oneOnOneOff)
    #expect(ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000 * 4).map(\.sampleTime) == [0, 96_000])
}

@Test func beatSkipBeatOneOnly() {
    let s = MetronomeSettings(bpm: 60, pattern: .quarter, beatSkip: .beatOneOnly)
    #expect(ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000 * 8).map(\.sampleTime) == [0, 192_000])
}

@Test func clickPatternLevels() {
    let e = ClickSchedule.events(settings: MetronomeSettings(bpm: 60, pattern: .eighths), sampleRate: sr, from: 0, to: 48_000)
    #expect(e.map(\.sampleTime) == [0, 24_000])
    #expect(e.map(\.level) == [4, 3])
}

@Test func tripletPatternTiming() {
    let e = ClickSchedule.events(settings: MetronomeSettings(bpm: 60, pattern: .triplets), sampleRate: sr, from: 0, to: 48_000)
    #expect(e.map(\.sampleTime) == [0, 16_000, 32_000])
}

@Test func accentBeatOneUsesLevel5() {
    let s = MetronomeSettings(bpm: 60, pattern: .quarter, accentBeatOne: true)
    let e = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000 * 4)
    #expect(e.map(\.level) == [5, 4, 4, 4])
    #expect(e[0].tone == ToneLadder.default[5])
}

@Test func slotSoundOverridesLadder() {
    var p = ClickPattern.eighths
    p.slots[2].sound = .rimshot
    let e = ClickSchedule.events(settings: MetronomeSettings(bpm: 60, pattern: p), sampleRate: sr, from: 0, to: 48_000)
    #expect(e[1].tone.sound == .rimshot)
    #expect(e[1].tone.pitchHz == ToneLadder.default[3]!.pitchHz)
    #expect(e[1].tone.gainDb == ToneLadder.default[3]!.gainDb)
}

@Test func levelsHaveDistinctTones() {
    let tones = (1...5).compactMap { ToneLadder.default[$0] }
    #expect(tones.count == 5)
    #expect(Set(tones.map { "\($0.sound)-\($0.pitchHz)" }).count == 5)
    #expect(tones.map(\.gainDb) == tones.map(\.gainDb).sorted())   // level 1 quietest … level 5 loudest
}

@Test func voiceSyllables() {
    let s = MetronomeSettings(bpm: 60, pattern: .quarter, voiceCount: .sixteenths)
    let voices = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000).filter {
        if case .voice = $0.kind { return true } else { return false }
    }
    #expect(voices.map(\.kind) == [.voice("1"), .voice("e"), .voice("&"), .voice("a")])
    #expect(voices.map(\.sampleTime) == [0, 12_000, 24_000, 36_000])
}

@Test func eightTimeUsesEighthBeats() {
    // 7/8 at ♩=60: each eighth lasts 0.5 s; bar = 3.5 s.
    let s = MetronomeSettings(bpm: 60, timeSignature: TimeSignature(beats: 7, unit: 8), pattern: .quarter)
    let e = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000 * 4)
    #expect(e.prefix(2).map(\.sampleTime) == [0, 24_000])
    #expect(e[7].kind == .downbeat && e[7].sampleTime == 168_000)
}

@Test func syllableFitsSlot() {
    let slot = 60.0 / 90 / 4
    let f = CountVoiceBank.stretchFactor(syllableDuration: 0.35, slot: slot)
    #expect(f < 1)
    #expect(f * 0.35 <= 0.9 * slot + 1e-9)
    #expect(CountVoiceBank.stretchFactor(syllableDuration: 0.1, slot: 1) == 1)
}

@Test func swungEighthClicks() {
    var s = MetronomeSettings(bpm: 60, pattern: .eighths)
    s.swing = 2.0 / 3.0
    let e = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000)
    #expect(e.map(\.sampleTime) == [0, 32_000])
}
