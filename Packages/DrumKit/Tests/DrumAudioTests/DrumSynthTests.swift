import DrumCore
import Testing
@testable import DrumAudio

@Test func everyVoiceHasASound() {
    for v in Voice.allCases {
        let s = DrumSynth.render(v, sampleRate: 48_000)
        #expect(!s.isEmpty && (s.map(abs).max() ?? 0) > 0.1 && (s.map(abs).max() ?? 0) <= 1, "\(v)")
    }
}

@Test func patternRenderPlacesNotes() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 1\nSN: x-x-")
    let audio = DrumSynth.renderPattern(ex, bpm: 60, countInBars: 1, sampleRate: 1_000)
    #expect(audio.count == 8 * 1_000)                     // 1 bar count-in + 1 bar at 60 BPM
    #expect(abs(audio[4_000]) > 0 || abs(audio[4_001]) > 0) // snare on beat 1 after count-in
    #expect(audio[5_500...5_900].allSatisfy { abs($0) < 0.05 })   // beat 2 is a rest (only decay)
}
