import DrumAI
import SwiftUI

/// One-time setup: Notion integration token + DrumCoach page, then the Claude Project instructions to paste.
struct TeacherSetupView: View {
    @Environment(\.modelContext) private var context
    @State private var token = Keychain.get(Keychain.notionToken) ?? ""
    @State private var link = ""
    @State private var working = false
    @State private var message: String?
    @State private var copied = false

    var body: some View {
        Form {
            Section("Bước 1 · Notion integration") {
                Text("Vào notion.so/my-integrations → New integration (Internal) → copy \"Internal Integration Secret\".")
                    .font(.callout)
                SecureField("secret_… / ntn_…", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section("Bước 2 · Trang DrumCoach") {
                Text("Tạo một trang tên \"DrumCoach\" trong Notion → ⋯ → Connections → thêm integration vừa tạo → Copy link trang.")
                    .font(.callout)
                TextField("https://www.notion.so/DrumCoach-…", text: $link).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(working ? "Đang tạo…" : "Kết nối và tạo các trang con") { Task { await connect() } }
                    .disabled(working || token.isEmpty || link.isEmpty)
                if TeacherConnection.isConfigured { Label("Đã kết nối Notion", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                if let message { Text(message).foregroundStyle(.secondary) }
            }
            Section {
                Text("Trên claude.ai: Projects → New project \"Thầy dạy trống\" → Project instructions: dán đoạn hướng dẫn dưới đây. Bật connector Notion và Web search.")
                    .font(.callout)
                Button(copied ? "Đã copy ✓" : "Copy hướng dẫn cho Project") {
                    UIPasteboard.general.string = TeacherProjectKit.projectInstructions(exerciseCatalog: ExerciseCatalog.titles(context))
                    copied = true
                }
            } header: {
                Text("Bước 3 · Claude Project")
            } footer: {
                Text("Khi thư viện có thêm nhiều bài mới, copy lại và cập nhật Project để thầy biết các bài đó.")
            }
        }
        .navigationTitle("Kết nối thầy AI")
    }

    private func connect() async {
        working = true; defer { working = false }
        do {
            try await TeacherConnection.setUp(token: token, rootLink: link)
            message = "Đã tạo Hộp thư, Kế hoạch, Bài tập mới trong trang DrumCoach."
        } catch {
            message = "Không kết nối được: \(Friendly.message(error))"
        }
    }
}
