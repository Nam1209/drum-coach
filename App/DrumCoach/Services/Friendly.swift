import DrumAI
import Foundation

/// User-facing text for any error thrown by the teacher/Notion/Claude paths.
enum Friendly {
    static func message(_ error: Error) -> String {
        switch error {
        case let e as ClaudeError: e.userMessage
        case let e as NotionError: e.userMessage
        case let e as BridgeError: e.userMessage
        case let e as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(e.code):
            "Không có kết nối mạng. Kiểm tra Wi-Fi rồi thử lại."
        default: error.localizedDescription
        }
    }
}
