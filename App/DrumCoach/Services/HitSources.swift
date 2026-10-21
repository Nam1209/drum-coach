import DrumAnalysis
import DrumAudio

/// Builds the hit source for an input mode, with its saved calibration applied.
@MainActor
enum HitSources {
    static func make(for mode: InputMode, calibrated: Bool = true) -> (any HitSource)? {
        let offset = calibrated ? SettingsStore.latency(for: mode) : 0
        switch mode {
        case .pad: return MicOnsetSource(calibrationOffset: offset)
        case .eDrum: return MIDIHitSource(overrides: SettingsStore.midiMap(), calibrationOffset: offset)
        case .listenOnly: return nil
        }
    }
}
