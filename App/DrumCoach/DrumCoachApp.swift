import DrumAudio
import SwiftUI

@main
struct DrumCoachApp: App {
    private let voiceBank = CountVoiceBank()

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Tập", systemImage: "music.note") {
                    PracticeView(exercises: StarterExercises.all, voiceBank: voiceBank)
                }
                Tab("Metronome", systemImage: "metronome") {
                    MetronomeView(voiceBank: voiceBank)
                }
            }
            .tint(.orange)
            .task { await voiceBank.prepare() }
        }
    }
}
