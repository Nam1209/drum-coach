import Foundation
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

@Test func swungClicksSurviveSmallRenderWindows() {
    // The audio thread asks for ~256 samples at a time; the swung "&" must not fall between windows.
    var s = MetronomeSettings(bpm: 120, pattern: .eighths, voiceCount: .eighths)
    s.swing = 2.0 / 3.0
    let whole = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 96_000)
    var pieces: [ClickEvent] = []
    var t: Int64 = 0
    while t < 96_000 {
        pieces += ClickSchedule.events(settings: s, sampleRate: sr, from: t, to: min(t + 256, 96_000))
        t += 256
    }
    #expect(pieces.sorted { ($0.sampleTime, $0.level) < ($1.sampleTime, $1.level) } == whole.sorted { ($0.sampleTime, $0.level) < ($1.sampleTime, $1.level) })
    #expect(pieces.contains { $0.sampleTime == 16_000 && $0.kind == .subdivision })   // & of beat 1 at 2/3 of 0.5 s
}

@Test func swingOnlyMovesEighthClicksInQuarterMeters() {
    var sixteen = MetronomeSettings(bpm: 60, pattern: .sixteenths)
    sixteen.swing = 0.72
    #expect(ClickSchedule.events(settings: sixteen, sampleRate: sr, from: 0, to: 48_000).map(\.sampleTime) == [0, 12_000, 24_000, 36_000])
    var triplet = MetronomeSettings(bpm: 60, pattern: .triplets)
    triplet.swing = 0.72
    #expect(ClickSchedule.events(settings: triplet, sampleRate: sr, from: 0, to: 48_000).map(\.sampleTime) == [0, 16_000, 32_000])
    var sevenEight = MetronomeSettings(bpm: 60, timeSignature: TimeSignature(beats: 7, unit: 8), pattern: .eighths)
    sevenEight.swing = 2.0 / 3.0
    #expect(ClickSchedule.events(settings: sevenEight, sampleRate: sr, from: 0, to: 24_000).map(\.sampleTime) == [0, 12_000])
}

@Test func compoundMetersClickOnDottedQuarters() {
    // 12/8 at ♩=90: an 8th lasts 1/3 s, so a dotted-quarter beat lasts 1 s and a bar has 4 beats.
    let s = MetronomeSettings(bpm: 90, timeSignature: TimeSignature(beats: 12, unit: 8), pattern: .quarter)
    let e = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000 * 5)
    #expect(e.map(\.sampleTime) == [0, 48_000, 96_000, 144_000, 192_000])
    #expect(e.map(\.kind) == [.downbeat, .beat, .beat, .beat, .downbeat])
    #expect(s.beatsPerBar == 4)
}

@Test func compoundMetersSubdivideInThrees() {
    // 6/8 with the triplet pattern: every 8th sounds, beats on 1 and 4.
    let s = MetronomeSettings(bpm: 90, timeSignature: TimeSignature(beats: 6, unit: 8), pattern: .triplets, voiceCount: .triplets)
    let clicks = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 96_000).filter { if case .voice = $0.kind { false } else { true } }
    #expect(clicks.map(\.sampleTime) == [0, 16_000, 32_000, 48_000, 64_000, 80_000])
    let voice = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 96_000).compactMap { if case .voice(let l) = $0.kind { l } else { nil } }
    #expect(voice == ["1", "trip", "let", "2", "trip", "let"])
}

@Test func syllablesAreResampledForTheOutputDevice() {
    // 0.1 s of a 1 kHz tone recorded at 48 kHz, played on a 44.1 kHz USB DAC.
    let tone = (0..<4_800).map { Float(sin(2 * Double.pi * 1_000 * Double($0) / 48_000)) }
    let out = CountVoiceBank.resample(tone, from: 48_000, to: 44_100)
    #expect(abs(out.count - 4_410) <= 1)                                  // still 0.1 s long
    let crossings = zip(out, out.dropFirst()).filter { $0 < 0 && $1 >= 0 }.count
    #expect((99...101).contains(crossings))                               // still 1 kHz, not 918 Hz
    #expect(CountVoiceBank.resample(tone, from: 48_000, to: 48_000) == tone)
}

/// Goertzel power at `f` Hz (48 kHz audio).
private func power(_ x: [Float], at f: Double) -> Double {
    let k = 2 * cos(2 * Double.pi * f / 48_000)
    var s1 = 0.0, s2 = 0.0
    for v in x { let s0 = Double(v) + k * s1 - s2; s2 = s1; s1 = s0 }
    return s1 * s1 + s2 * s2 - k * s1 * s2
}

private func db(_ ratio: Double) -> Double { 10 * log10(ratio) }

/// The user's analysis of the wooden metronome they want: transient + inharmonic resonances peaking at 1195 Hz.
@Test func mechanicalClickMatchesTheReferenceSpectrum() {
    let s = ClickSynth.render(sound: .mechanical, pitchHz: 1_195, sampleRate: 48_000)
    let main = power(s, at: 1_195)
    for f in [1_037.0, 393, 3_463, 2_695, 5_268, 527, 914, 3_803, 4_113] { #expect(power(s, at: f) < main, "\(f) Hz") }
    #expect(db(power(s, at: 393) / main) > db(power(s, at: 5_268) / main))      // body −10 dB above the −18 dB shimmer
    #expect(db(power(s, at: 120) / main) < -25)                                  // almost nothing below 300 Hz
    // Sharp: the peak comes within ~1 ms, and the level is 20 dB down 7–10 ms later.
    let peakIndex = s.indices.max { abs(s[$0]) < abs(s[$1]) }!
    #expect(peakIndex <= 72)                                                     // 1.5 ms
    func rms(_ from: Int, _ n: Int) -> Double { sqrt(s[from..<min(from + n, s.count)].reduce(0) { $0 + Double($1 * $1) } / Double(n)) }
    #expect(20 * log10(rms(peakIndex + 432, 48) / rms(max(0, peakIndex - 24), 48)) < -14)   // ~10 ms after the peak
    #expect(s.count <= Int(0.17 * 48_000))
}

@Test func defaultClicksHaveNoHighRingingBeeps() {
    #expect(ToneLadder.default.values.allSatisfy { $0.pitchHz <= 1_300 })
}

@Test func clockTickFactoryLadderIsUpgradedToo() {
    #expect(ToneLadder.upgraded(ToneLadder.clockTickDefault) == ToneLadder.default)
}

@Test func woodblockFactoryLadderIsUpgradedToo() {
    #expect(ToneLadder.upgraded(ToneLadder.woodblockDefault) == ToneLadder.default)
}

@Test func savedFactoryLadderIsUpgradedButCustomOnesAreKept() {
    #expect(ToneLadder.upgraded(ToneLadder.legacyDefault) == ToneLadder.default)
    var custom = ToneLadder.legacyDefault
    custom[5]?.pitchHz = 1500
    #expect(ToneLadder.upgraded(custom) == custom)
}

@Test func firstFactorySettingsBecomeASimpleTickTock() {
    var old = MetronomeSettings(bpm: 70, pattern: .eighths, accentBeatOne: true)
    old.ladder = ToneLadder.legacyDefault
    let new = old.upgradedFromFirstRelease()
    #expect(new.pattern == .quarter && new.ladder == ToneLadder.default && new.bpm == 70)
    // A user's own pattern or sounds are left alone.
    var custom = old; custom.pattern = .sixteenths
    #expect(custom.upgradedFromFirstRelease().pattern == .sixteenths)
    // Tick on 1, the same soft tock on 2, 3, 4.
    let e = ClickSchedule.events(settings: MetronomeSettings(bpm: 60, pattern: .quarter, accentBeatOne: true), sampleRate: sr, from: 0, to: 48_000 * 4)
    #expect(e.map(\.tone).dropFirst().allSatisfy { $0 == e[1].tone } && e[0].tone != e[1].tone)
}

@Test func countInIsSpokenOneTwoThreeFour() {
    var s = MetronomeSettings(bpm: 60, pattern: .quarter)
    s.spokenCountInBars = 1
    let voice = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000 * 8).compactMap { e -> (Int64, String)? in
        if case .voice(let l) = e.kind { (e.sampleTime, l) } else { nil }
    }
    #expect(voice.map(\.1) == ["1", "2", "3", "4"])                         // only during the count-in bar
    #expect(voice.map(\.0) == [0, 48_000, 96_000, 144_000])
}

@Test func countInIsNotDoubledWhenCountingIsOn() {
    var s = MetronomeSettings(bpm: 60, pattern: .quarter, voiceCount: .quarters)
    s.spokenCountInBars = 1
    let first = ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: 48_000).filter { if case .voice = $0.kind { true } else { false } }
    #expect(first.count == 1)
}

@Test func everyEarlierFactoryLadderUpgradesToTheCurrentOne() {
    #expect(ToneLadder.factoryLadders.contains(ToneLadder.brightWoodDefault))
    #expect(ToneLadder.factoryLadders.contains(ToneLadder.deepWoodDefault))
    for ladder in ToneLadder.factoryLadders { #expect(ToneLadder.upgraded(ladder) == ToneLadder.default) }
    #expect(!ToneLadder.factoryLadders.contains(ToneLadder.default))
}
