import AVFoundation

/// Microphone access, asked for when it is first needed.
enum MicPermission {
    /// True when the app may use the mic (asks the first time).
    static func ensure() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}
