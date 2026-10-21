/// Short Vietnamese messages for errors the user can act on (no raw enum dumps in the UI).
extension ClaudeError {
    public var userMessage: String {
        switch self {
        case .missingKey: "Chưa có API key Claude — nhập trong Cài đặt, hoặc dùng gói Claude Pro qua Notion."
        case .network: "Không có kết nối mạng tới Claude. Kiểm tra Wi-Fi rồi thử lại."
        case .http(401, _), .http(403, _): "API key Claude không đúng hoặc đã bị thu hồi. Kiểm tra lại trong Cài đặt."
        case .http(429, _): "Đã gửi quá nhiều yêu cầu. Đợi một lát rồi thử lại."
        case .http(let code, _) where code >= 500: "Claude đang bận hoặc gặp sự cố. Thử lại sau ít phút."
        case .http(let code, _): "Claude trả lỗi \(code). Thử lại sau."
        case .refused: "Claude từ chối yêu cầu này. Thử diễn đạt lại."
        case .decoding: "Câu trả lời của Claude không đúng định dạng. Thử lại lần nữa."
        }
    }
}

extension NotionError {
    public var userMessage: String {
        switch self {
        case .http(401, _): "Notion token không đúng. Tạo lại integration và dán token mới."
        case .http(403, _), .http(404, _): "Integration chưa được cấp quyền vào trang DrumCoach (⋯ → Connections → thêm integration)."
        case .http(413, _): "Dữ liệu gửi lên Notion quá lớn."
        case .http(429, _): "Notion đang giới hạn số yêu cầu. Thử lại sau ít phút."
        case .http(let code, _): "Notion trả lỗi \(code). Thử lại sau."
        case .badResponse: "Notion trả về dữ liệu không đọc được, hoặc link trang DrumCoach không đúng."
        }
    }
}

extension BridgeError {
    public var userMessage: String {
        switch self {
        case .noJSONBlock: "Trang kế hoạch chưa có khối JSON (có thể Claude chưa viết xong) — sẽ thử lại ở lần đồng bộ sau."
        case .invalidJSON: "Khối JSON trong trang kế hoạch bị hỏng — nhờ Claude viết lại khối JSON."
        case .schemaMismatch: "Kế hoạch thiếu trường bắt buộc — nhờ Claude viết đúng schema trong hướng dẫn Project."
        }
    }
}
