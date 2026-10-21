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
                Tab("Level", systemImage: "trophy") {
                    NavigationStack { LevelListView(voiceBank: voiceBank) }
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
                Tab("Cài đặt", systemImage: "gearshape") {
                    NavigationStack { SettingsView(voiceBank: voiceBank) }
                }
            }
            .tint(.orange)
            .task {
                VoiceRecorder.loadAll(into: voiceBank)
                await voiceBank.prepare()
            }
            .modelContainer(for: [PracticeSession.self, StoredExercise.self])
        }
    }
}
