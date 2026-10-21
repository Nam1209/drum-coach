import DrumAI
import DrumCore
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
            Section(L("Bước 1 · Notion integration", "Step 1 · Notion integration")) {
                Text(L("Vào notion.so/my-integrations → New integration (Internal) → copy \"Internal Integration Secret\".", "Go to notion.so/my-integrations → New integration (Internal) → copy the \"Internal Integration Secret\"."))
                    .font(.callout)
                SecureField("secret_… / ntn_…", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section(L("Bước 2 · Trang DrumCoach", "Step 2 · DrumCoach page")) {
                Text(L("Tạo một trang tên \"DrumCoach\" trong Notion → ⋯ → Connections → thêm integration vừa tạo → Copy link trang.", "Create a page named \"DrumCoach\" in Notion → ⋯ → Connections → add the integration you just made → Copy link to the page."))
                    .font(.callout)
                TextField("https://www.notion.so/DrumCoach-…", text: $link).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(working ? L("Đang tạo…", "Creating…") : L("Kết nối và tạo các trang con", "Connect and create subpages")) { Task { await connect() } }
                    .disabled(working || token.isEmpty || link.isEmpty)
                if TeacherConnection.isConfigured { Label(L("Đã kết nối Notion", "Notion connected"), systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                if let message { Text(message).foregroundStyle(.secondary) }
            }
            Section {
                Text(L("Trên claude.ai: Projects → New project \"Thầy dạy trống\" → Project instructions: dán đoạn hướng dẫn dưới đây. Bật connector Notion và Web search.", "On claude.ai: Projects → New project \"Thầy dạy trống\" → Project instructions: paste the instructions below. Turn on the Notion connector and Web search."))
                    .font(.callout)
                Button(copied ? L("Đã copy ✓", "Copied ✓") : L("Copy hướng dẫn cho Project", "Copy instructions for the Project")) {
                    UIPasteboard.general.string = TeacherProjectKit.projectInstructions(exerciseCatalog: ExerciseCatalog.titles(context))
                    copied = true
                }
            } header: {
                Text(L("Bước 3 · Claude Project", "Step 3 · Claude Project"))
            } footer: {
                Text(L("Khi thư viện có thêm nhiều bài mới, copy lại và cập nhật Project để thầy biết các bài đó.", "When the library gets new exercises, copy again and update the Project so the teacher knows about them."))
            }
        }
        .navigationTitle(L("Kết nối thầy AI", "Connect the AI teacher"))
    }

    private func connect() async {
        working = true; defer { working = false }
        do {
            try await TeacherConnection.setUp(token: token, rootLink: link)
            message = L("Đã tạo Hộp thư, Kế hoạch, Bài tập mới trong trang DrumCoach.", "Created Inbox, Plans and New exercises in the DrumCoach page.")
        } catch {
            message = L("Không kết nối được: \(Friendly.message(error))", "Could not connect: \(Friendly.message(error))")
        }
    }
}
