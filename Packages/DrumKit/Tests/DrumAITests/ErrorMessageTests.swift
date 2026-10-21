import Testing
@testable import DrumAI

@Test(.vietnamese) func claudeErrorsReadableInVietnamese() {
    #expect(ClaudeError.network("x").userMessage.contains("mạng"))
    #expect(ClaudeError.http(401, "invalid x-api-key").userMessage.contains("API key"))
    #expect(ClaudeError.http(529, "overloaded").userMessage.contains("bận"))
    #expect(ClaudeError.decoding("keyNotFound(CodingKeys…").userMessage.contains("không đúng định dạng"))
    #expect(!ClaudeError.decoding("keyNotFound(CodingKeys…").userMessage.contains("CodingKeys"))
    #expect(ClaudeError.refused(nil).userMessage.contains("từ chối"))
    #expect(ClaudeError.missingKey.userMessage.contains("Cài đặt"))
}

@Test(.vietnamese) func notionErrorsReadable() {
    #expect(NotionError.http(401, "x").userMessage.contains("token"))
    #expect(NotionError.http(404, "x").userMessage.contains("Connections"))
    #expect(NotionError.http(413, "x").userMessage.contains("lớn"))
    #expect(BridgeError.invalidJSON("{").userMessage.contains("JSON"))
}
