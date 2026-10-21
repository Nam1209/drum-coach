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
                Tab("Thầy AI", systemImage: "person.crop.circle.badge.checkmark") {
                    NavigationStack { TeacherView() }
                }
                Tab("Level", systemImage: "trophy") {
                    NavigationStack { LevelListView(voiceBank: voiceBank) }
                }
                Tab("Tiến độ", systemImage: "chart.line.uptrend.xyaxis") {
                    NavigationStack {
                        List {
                            NavigationLink("Hành trình") { JourneyView() }
                            NavigationLink("Lịch sử & backup") { HistoryView() }
                        }
                        .navigationTitle("Tiến độ")
                    }
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
            .tabViewStyle(.sidebarAdaptable)
            .tint(.orange)
            .modifier(AutoBackup())
            .task {
                VoiceRecorder.loadAll(into: voiceBank)
                await voiceBank.prepare()
            }
            .modelContainer(for: [PracticeSession.self, StoredExercise.self, JournalEntry.self, StoredReport.self])
        }
    }
}

/// Runs the weekly automatic backup when the app becomes active.
private struct AutoBackup: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    func body(content: Content) -> some View {
        content.onChange(of: phase, initial: true) { _, p in if p == .active { HistoryStore.autoBackupIfDue(context) } }
    }
}
