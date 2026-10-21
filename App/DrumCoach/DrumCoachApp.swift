import DrumAudio
import SwiftUI

@main
struct DrumCoachApp: App {
    private let voiceBank = CountVoiceBank()

    var body: some Scene {
        WindowGroup {
            MetronomeView(voiceBank: voiceBank)
                .tint(.orange)
        }
    }
}
