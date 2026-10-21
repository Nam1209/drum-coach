import DrumCore
/// Short Vietnamese messages for errors the user can act on (no raw enum dumps in the UI).
extension ClaudeError {
    public var userMessage: String {
        switch self {
        case .missingKey: L("Chưa có API key Claude — nhập trong Cài đặt, hoặc dùng gói Claude Pro qua Notion.", "No Claude API key — add one in Settings, or use your Claude Pro plan through Notion.")
        case .network: L("Không có kết nối mạng tới Claude. Kiểm tra Wi-Fi rồi thử lại.", "Can't reach Claude. Check Wi-Fi and try again.")
        case .http(401, _), .http(403, _): L("API key Claude không đúng hoặc đã bị thu hồi. Kiểm tra lại trong Cài đặt.", "The Claude API key is wrong or revoked. Check it in Settings.")
        case .http(429, _): L("Đã gửi quá nhiều yêu cầu. Đợi một lát rồi thử lại.", "Too many requests. Wait a moment and try again.")
        case .http(let code, _) where code >= 500: L("Claude đang bận hoặc gặp sự cố. Thử lại sau ít phút.", "Claude is busy or having trouble. Try again in a few minutes.")
        case .http(let code, _): L("Claude trả lỗi \(code). Thử lại sau.", "Claude returned error \(code). Try again later.")
        case .refused: L("Claude từ chối yêu cầu này. Thử diễn đạt lại.", "Claude declined this request. Try rephrasing it.")
        case .decoding: L("Câu trả lời của Claude không đúng định dạng. Thử lại lần nữa.", "Claude's reply was malformed. Please try again.")
        }
    }
}

extension NotionError {
    public var userMessage: String {
        switch self {
        case .http(401, _): L("Notion token không đúng. Tạo lại integration và dán token mới.", "The Notion token is wrong. Recreate the integration and paste the new token.")
        case .http(403, _), .http(404, _): L("Integration chưa được cấp quyền vào trang DrumCoach (⋯ → Connections → thêm integration).", "The integration has no access to the DrumCoach page (⋯ → Connections → add the integration).")
        case .http(413, _): L("Dữ liệu gửi lên Notion quá lớn.", "The data sent to Notion is too large.")
        case .http(429, _): L("Notion đang giới hạn số yêu cầu. Thử lại sau ít phút.", "Notion is rate-limiting requests. Try again in a few minutes.")
        case .http(let code, _): L("Notion trả lỗi \(code). Thử lại sau.", "Notion returned error \(code). Try again later.")
        case .badResponse: L("Notion trả về dữ liệu không đọc được, hoặc link trang DrumCoach không đúng.", "Notion returned unreadable data, or the DrumCoach page link is wrong.")
        }
    }
}

extension BridgeError {
    public var userMessage: String {
        switch self {
        case .noJSONBlock: L("Trang kế hoạch chưa có khối JSON (có thể Claude chưa viết xong) — sẽ thử lại ở lần đồng bộ sau.", "The plan page has no JSON block yet (Claude may still be writing) — will retry on the next sync.")
        case .invalidJSON: L("Khối JSON trong trang kế hoạch bị hỏng — nhờ Claude viết lại khối JSON.", "The JSON block on the plan page is broken — ask Claude to rewrite it.")
        case .schemaMismatch: L("Kế hoạch thiếu trường bắt buộc — nhờ Claude viết đúng schema trong hướng dẫn Project.", "The plan is missing required fields — ask Claude to follow the schema in the Project instructions.")
        }
    }
}
