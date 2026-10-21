import DrumAnalysis
import DrumAudio
import DrumCore
import Foundation

/// Small preferences persisted in UserDefaults as JSON.
enum SettingsStore {
    private static let metronomeKey = "metronomeSettings.v1"

    static func loadMetronome() -> MetronomeSettings? {
        guard let data = UserDefaults.standard.data(forKey: metronomeKey) else { return nil }
        guard var s = try? JSONDecoder().decode(MetronomeSettings.self, from: data) else { return nil }
        return s.upgradedFromFirstRelease()
    }

    /// Measured extra latency (seconds) per input mode, kept separately for each output device (speaker, GO link,
    /// AirPods…) because each adds its own delay. Falls back to the last value measured on any device.
    static func latency(for mode: InputMode) -> TimeInterval {
        let d = UserDefaults.standard
        return d.object(forKey: deviceKey(mode)) == nil ? d.double(forKey: "latency.\(mode.rawValue)") : d.double(forKey: deviceKey(mode))
    }

    static func setLatency(_ value: TimeInterval, for mode: InputMode) {
        UserDefaults.standard.set(value, forKey: "latency.\(mode.rawValue)")
        UserDefaults.standard.set(value, forKey: deviceKey(mode))
    }

    /// True when this input has been calibrated with the output device in use now.
    static func isCalibratedForCurrentOutput(_ mode: InputMode) -> Bool {
        UserDefaults.standard.object(forKey: deviceKey(mode)) != nil
    }

    private static func deviceKey(_ mode: InputMode) -> String { "latency.\(mode.rawValue).\(AudioSessionConfig.outputName)" }

    /// The pad and room measured with 8 taps (nil = not done yet: the default sensitivity is used).
    static var padProfile: PadProfile? {
        get { UserDefaults.standard.data(forKey: "padProfile.v1").flatMap { try? JSONDecoder().decode(PadProfile.self, from: $0) } }
        set { UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "padProfile.v1") }
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

    /// Dễ / Vừa / Khó: how close a hit must be to count as green.
    static var scoring: ScoringRules {
        get {
            let ms = UserDefaults.standard.double(forKey: "goodWindowMs")
            return ms > 0 ? ScoringRules(goodWindow: ms / 1000) : ScoringRules()
        }
        set { UserDefaults.standard.set(newValue.goodWindow * 1000, forKey: "goodWindowMs") }
    }

    /// Highest Rockschool grade passed in the level tests (0 = none yet).
    static var currentGrade: Int {
        get { UserDefaults.standard.integer(forKey: "currentGrade") }
        set { UserDefaults.standard.set(newValue, forKey: "currentGrade") }
    }

    /// When each level was first reached (for the journey timeline).
    static var levelHistory: [(Int, Date)] {
        let raw = UserDefaults.standard.dictionary(forKey: "levelHistory") as? [String: Date] ?? [:]
        return raw.compactMap { k, v in Int(k).map { ($0, v) } }.sorted { $0.0 < $1.0 }
    }

    static func markLevelReached(_ level: Int, at date: Date = Date()) {
        var raw = UserDefaults.standard.dictionary(forKey: "levelHistory") as? [String: Date] ?? [:]
        if raw[String(level)] == nil { raw[String(level)] = date }
        UserDefaults.standard.set(raw, forKey: "levelHistory")
    }

    static func saveMetronome(_ s: MetronomeSettings) {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: metronomeKey) }
    }
}
