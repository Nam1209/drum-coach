import DrumAI
import DrumCore
import Foundation

/// User-facing text for any error thrown by the teacher/Notion/Claude paths.
enum Friendly {
    static func message(_ error: Error) -> String {
        switch error {
        case let e as ClaudeError: e.userMessage
        case let e as NotionError: e.userMessage
        case let e as BridgeError: e.userMessage
        case let e as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(e.code):
            L("Không có kết nối mạng. Kiểm tra Wi-Fi rồi thử lại.", "No network connection. Check Wi-Fi and try again.")
        default: error.localizedDescription
        }
    }
}
