import DrumAudio
import SwiftData
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
                Tab("Thư viện", systemImage: "books.vertical") {
                    NavigationStack { LibraryView(voiceBank: voiceBank) }
                }
                Tab("Đếm nhịp", systemImage: "waveform") {
                    NavigationStack { CountCoachView(voiceBank: voiceBank) }
                }
                Tab("Metronome", systemImage: "metronome") {
                    MetronomeView(voiceBank: voiceBank)
                }
            }
            .tint(.orange)
            .task { await voiceBank.prepare() }
            .modelContainer(for: [PracticeSession.self, StoredExercise.self])
        }
    }
}
