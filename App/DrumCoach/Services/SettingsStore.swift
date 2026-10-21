import DrumAudio
import DrumCore
import Foundation

/// Small preferences persisted in UserDefaults as JSON.
enum SettingsStore {
    private static let metronomeKey = "metronomeSettings.v1"

    static func loadMetronome() -> MetronomeSettings? {
        guard let data = UserDefaults.standard.data(forKey: metronomeKey) else { return nil }
        return try? JSONDecoder().decode(MetronomeSettings.self, from: data)
    }

    /// Measured extra latency (seconds) per input mode.
    static func latency(for mode: InputMode) -> TimeInterval {
        UserDefaults.standard.double(forKey: "latency.\(mode.rawValue)")
    }

    static func setLatency(_ value: TimeInterval, for mode: InputMode) {
        UserDefaults.standard.set(value, forKey: "latency.\(mode.rawValue)")
    }

    /// MIDI note → drum overrides learned from the user's kit (Task 16 MIDI learn).
    static func midiMap() -> [UInt8: Voice] {
        guard let data = UserDefaults.standard.data(forKey: "midiMap.v1"),
              let raw = try? JSONDecoder().decode([String: Voice].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in UInt8(k).map { ($0, v) } })
    }

    static func saveMidiMap(_ map: [UInt8: Voice]) {
        let raw = Dictionary(uniqueKeysWithValues: map.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(raw) { UserDefaults.standard.set(data, forKey: "midiMap.v1") }
    }

    static func saveMetronome(_ s: MetronomeSettings) {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: metronomeKey) }
    }
}
