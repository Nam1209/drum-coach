import Testing
@testable import DrumAudio

@Test(arguments: [ClickSound.click, .beep, .woodblock, .cowbell, .hiHat, .rimshot])
func everySoundRendersAudibleAndBounded(sound: ClickSound) {
    let samples = ClickSynth.render(sound: sound, pitchHz: 1000, sampleRate: 48_000)
    let peak = samples.map(abs).max() ?? 0
    #expect(peak > 0.2)
    #expect(peak <= 1.0)
    #expect(samples.count >= 48 * 20 && samples.count <= 48 * 250)   // 20–250 ms
    #expect(abs(samples.last!) < 0.01)                                // decays to silence, no click at the end
}

@Test func pitchChangesWaveform() {
    let a = ClickSynth.render(sound: .beep, pitchHz: 880, sampleRate: 48_000)
    let b = ClickSynth.render(sound: .beep, pitchHz: 1760, sampleRate: 48_000)
    #expect(a != b)
}

@Test func gainConversion() {
    #expect(abs(ClickSynth.linearGain(db: -6.0206) - 0.5) < 1e-3)
    #expect(ClickSynth.linearGain(db: 0) == 1)
}
