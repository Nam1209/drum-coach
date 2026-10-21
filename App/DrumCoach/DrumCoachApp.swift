import DrumAudio
import DrumCore
import SwiftData
import SwiftUI

@main
struct DrumCoachApp: App {
    private let voiceBank = CountVoiceBank()

    init() {
        // The interface is Vietnamese until its English translation ships; keep content in the same language.
        Lang.current = .vi
    }

    var body: some Scene {
        WindowGroup {
            RootView(voiceBank: voiceBank)
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
