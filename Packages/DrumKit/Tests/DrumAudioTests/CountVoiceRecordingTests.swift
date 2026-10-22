import Foundation
import Testing
@testable import DrumAudio

/// A spoken "one" as the iPad mic records it: peak only ~0.03 inside a second of near silence.
private func quietWord(peak: Float = 0.03) -> [Float] {
    (0..<48_000).map { i in
        let t = Double(i) / 48_000
        let inWord = t > 0.3 && t < 0.55
        return inWord ? peak * Float(sin(2 * .pi * 220 * t)) : Float.random(in: -0.0005...0.0005)
    }
}

@Test func quietRecordingIsBoostedNotTrimmedAway() {
    let bank = CountVoiceBank()
    #expect(bank.setCustomSyllable("1", samples: quietWord()))
    let s = bank.samples(for: "1") ?? []
    #expect(Double(s.count) / 48_000 > 0.2)                  // the word survived trimming
    #expect((s.map(abs).max() ?? 0) > 0.5)                    // and is as loud as the built-in voice
}

@Test func silentRecordingIsRejectedAndKeepsTheVoice() {
    let bank = CountVoiceBank()
    bank.setCustomSyllable("1", samples: quietWord())
    let before = bank.samples(for: "1")
    #expect(!bank.setCustomSyllable("1", samples: [Float](repeating: 0, count: 48_000)))
    #expect(bank.samples(for: "1") == before)
}

@Test func removingARecordingFreesTheSlotForTheBuiltInVoice() {
    let bank = CountVoiceBank()
    bank.setCustomSyllable("1", samples: quietWord())
    bank.removeCustomSyllable("1")
    #expect(bank.samples(for: "1") == nil)                    // prepare() fills it again
}
