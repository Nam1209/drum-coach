import Testing
@testable import DrumAudio

@Test func realMetronomeRecordingsShipWithTheApp() {
    let ticks = ClickSynth.variants(sound: .metronome, pitchHz: 1_000, sampleRate: 48_000)
    #expect(ticks.count == 4)
    #expect(ticks.allSatisfy { (7_000...9_000).contains($0.count) && ($0.map(abs).max() ?? 0) > 0.5 })
    #expect(ClickSynth.variants(sound: .sticks, pitchHz: 1_000, sampleRate: 48_000).count == 2)
}

@Test func recordingsFollowTheOutputRateAndTuning() {
    let base = ClickSynth.variants(sound: .metronome, pitchHz: 1_000, sampleRate: 48_000)[0].count
    let dac = ClickSynth.variants(sound: .metronome, pitchHz: 1_000, sampleRate: 44_100)[0].count
    #expect(abs(dac - base * 441 / 480) <= 2)                                  // same duration on a 44.1 kHz DAC
    let higher = ClickSynth.variants(sound: .metronome, pitchHz: 1_030, sampleRate: 48_000)[0].count
    #expect(abs(Double(higher) - Double(base) / 1.03) <= 2)                    // tuned up 3% = played 3% faster
}

@Test func theMetronomeRotatesThroughItsRecordings() {
    let cache = MetronomeEngine.renderTones(ToneLadder.default, sampleRate: 48_000)
    #expect(cache[ToneLadder.default[4]!]?.count == 4)
}

@Test func defaultIsTheRealMechanicalMetronome() {
    #expect((2...5).allSatisfy { ToneLadder.default[$0]?.sound == .metronome })
    #expect(ToneLadder.factoryLadders.contains(ToneLadder.syntheticMechanicalDefault))
    #expect(ToneLadder.upgraded(ToneLadder.syntheticMechanicalDefault) == ToneLadder.default)
}
