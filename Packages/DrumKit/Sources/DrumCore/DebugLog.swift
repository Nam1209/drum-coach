import Foundation

/// Diagnostic lines for a laptop watching the app: launched with `-debugLog` (e.g. through
/// `xcrun devicectl device process launch --console`), every line goes to stderr, unbuffered, with the host uptime
/// in seconds so MIDI, microphone and scoring lines can be lined up. Off otherwise, and then costs nothing.
public enum DebugLog {
    public static let enabled = ProcessInfo.processInfo.arguments.contains("-debugLog")

    public static func line(_ text: @autoclosure () -> String) {
        guard enabled else { return }
        let s = String(format: "%.3f ", ProcessInfo.processInfo.systemUptime) + text() + "\n"
        FileHandle.standardError.write(Data(s.utf8))
    }
}
