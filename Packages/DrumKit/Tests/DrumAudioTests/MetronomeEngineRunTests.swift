import AVFoundation
import DrumCore
import Foundation
import Testing
@testable import DrumAudio

/// Runs the real audio engine: the render block is called on the audio thread, so a block that
/// inherited main-actor isolation crashes here exactly like it did on the iPad.
@MainActor
@Test(.timeLimit(.minutes(1))) func metronomeRendersOnTheAudioThreadWithoutCrashing() async throws {
    let engine = MetronomeEngine(voiceBank: CountVoiceBank())
    do { try engine.start(settings: MetronomeSettings(bpm: 120)) } catch {
        return   // no audio output device on this machine: nothing to check
    }
    try await Task.sleep(for: .milliseconds(600))
    #expect(engine.beatZeroHostTime != nil)          // render callbacks have run
    engine.stop()
}

/// The other real audio paths: each one is run for real so a callback with the wrong isolation crashes the test.
@MainActor
@Test(.timeLimit(.minutes(1))) func previewAndListenPlayWithoutCrashing() async throws {
    TonePreview().play(ToneLadder.default[4]!, volume: 0.1)
    let player = DrumPlayer()
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 2\nSN: x-x-x-x-")
    do { try player.play(ex, bpm: 240, countInBars: 0) } catch { return }   // no output device
    try await Task.sleep(for: .milliseconds(500))
    player.stop()
}

@MainActor
@Test(.timeLimit(.minutes(1))) func countVoicesAreSynthesisedWithoutCrashing() async {
    let bank = CountVoiceBank()
    await bank.prepare()      // voices may be missing on this machine; what matters is that the speech callbacks don't crash
}

@MainActor
@Test(.timeLimit(.minutes(1))) func backingTrackPlaysWithoutCrashing() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "silence-\(UUID().uuidString).caf")
    let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100)!
    buffer.frameLength = 44_100
    try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
    defer { try? FileManager.default.removeItem(at: url) }
    let player = BackingTrackPlayer()
    try player.load(url)
    do { try player.play(rate: 1, loopA: nil, loopB: nil, volume: 0.1) } catch { return }   // no output device
    try await Task.sleep(for: .milliseconds(400))
    player.stop()
}

/// The voice is rendered in the background at launch; a count started before it is ready must pick it up once it is.
@MainActor
@Test(.timeLimit(.minutes(1))) func countingVoiceArrivesAfterTheEngineStarted() async throws {
    let bank = CountVoiceBank()
    let engine = MetronomeEngine(voiceBank: bank)
    do { try engine.start(settings: MetronomeSettings(bpm: 90, voiceCount: .quarters)) } catch { return }
    defer { engine.stop() }
    #expect(engine.cachedSyllables.isEmpty)
    bank.setCustomSyllable("1", samples: (0..<4800).map { sin(Float($0) * 0.1) * 0.5 })
    try await Task.sleep(for: .milliseconds(200))
    #expect(engine.cachedSyllables.contains("1"))
}
