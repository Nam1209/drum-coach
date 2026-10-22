import DrumAudio
import DrumCore
import SwiftData
import SwiftUI

@main
struct DrumCoachApp: App {
    private let voiceBank = CountVoiceBank()
    /// "system" follows the device language.
    @AppStorage(AppLocale.key) private var language = "system"

    init() {
        AppLocale.apply(UserDefaults.standard.string(forKey: AppLocale.key) ?? "system")
    }

    var body: some Scene {
        WindowGroup {
            RootView(voiceBank: voiceBank)
            // Rebuild every screen in the new language when it changes in Settings.
            .id(AppLocale.apply(language))
            .environment(\.locale, AppLocale.current)
            .modifier(AutoBackup())
            .task {
                DrumConnectionMonitor.shared.start()
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
