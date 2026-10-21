import DrumAudio
import Foundation

/// Small preferences persisted in UserDefaults as JSON.
enum SettingsStore {
    private static let metronomeKey = "metronomeSettings.v1"

    static func loadMetronome() -> MetronomeSettings? {
        guard let data = UserDefaults.standard.data(forKey: metronomeKey) else { return nil }
        return try? JSONDecoder().decode(MetronomeSettings.self, from: data)
    }

    static func saveMetronome(_ s: MetronomeSettings) {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: metronomeKey) }
    }
}
