import DrumAnalysis
import DrumAudio
import Foundation

/// Builds the hit source for an input mode, with its saved calibration applied.
@MainActor
enum HitSources {
    static func make(for mode: InputMode, calibrated: Bool = true) -> (any HitSource)? {
        let offset = calibrated ? SettingsStore.latency(for: mode) : 0
        switch mode {
        case .pad:
            let profile = SettingsStore.padProfile
            return MicOnsetSource(calibrationOffset: offset) { rate in
                profile.map { OnsetDetector(sampleRate: rate, profile: $0) } ?? OnsetDetector(sampleRate: rate)
            }
        case .eDrum: return MIDIHitSource(overrides: SettingsStore.midiMap(), calibrationOffset: offset,
                                          hiHatByPedal: UserDefaults.standard.bool(forKey: "hiHatByPedal"))
        case .touch: return TouchHitSource(calibrationOffset: offset)
        case .listenOnly: return nil
        }
    }
}
