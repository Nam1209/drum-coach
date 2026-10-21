import DrumAI
import DrumCore
import SwiftUI

/// One-time setup: make a Notion integration that can see the DrumCoach page, then paste its secret. The app finds the
/// page itself, creates the subpages and writes the teacher guide, so no Claude Project is needed.
struct TeacherSetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var token = Keychain.get(Keychain.notionToken) ?? ""
    @State private var working = false
    @State private var message: String?
    @State private var connected = TeacherConnection.isConfigured

    var body: some View {
        Form {
            Section {
                Text(L("New integration → đặt tên DrumCoach → Save. Ở tab Access chọn trang DrumCoach. Ở tab Configuration bấm Show rồi Copy mã secret.",
                       "New integration → name it DrumCoach → Save. In the Access tab pick the DrumCoach page. In the Configuration tab tap Show, then Copy the secret."))
                    .font(.callout)
                Button(L("Mở Notion", "Open Notion")) {
                    if let url = URL(string: "https://www.notion.so/profile/integrations") { openURL(url) }
                }
            } header: {
                Text(L("Bước 1 · Tạo mã trên Notion", "Step 1 · Make a key in Notion"))
            } footer: {
                Text(L("Chưa có trang DrumCoach thì tạo một trang trống tên DrumCoach trước.", "No DrumCoach page yet? Create an empty page named DrumCoach first."))
            }
            Section {
                Button(working ? L("Đang kết nối…", "Connecting…") : L("Dán mã và kết nối", "Paste key and connect")) {
                    if let pasted = UIPasteboard.general.string, !pasted.isEmpty { token = pasted }
                    Task { await connect() }
                }
                .disabled(working)
                SecureField("ntn_… / secret_…", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onSubmit { Task { await connect() } }
                if connected { Label(L("Đã kết nối Notion", "Notion connected"), systemImage: "checkmark.circle.fill").foregroundStyle(Theme.onTime) }
                if let message { Text(message).foregroundStyle(.secondary) }
            } header: {
                Text(L("Bước 2 · Dán mã", "Step 2 · Paste the key"))
            } footer: {
                Text(L("App tự tìm trang DrumCoach, tạo Hộp thư, Kế hoạch, Bài tập mới và trang Hướng dẫn cho thầy. Trên claude.ai chỉ cần bật connector Notion (Settings → Connectors), không phải tạo Project.",
                       "The app finds the DrumCoach page and creates Inbox, Plans, New exercises and the Teacher guide page. On claude.ai just turn on the Notion connector (Settings → Connectors); no Project needed."))
            }
        }
        .navigationTitle(L("Kết nối thầy AI", "Connect the AI teacher"))
    }

    private func connect() async {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = L("Chưa có mã. Copy mã secret ở Bước 1 rồi bấm lại.", "No key yet. Copy the secret in step 1 and tap again.")
            return
        }
        working = true; defer { working = false }
        do {
            try await TeacherConnection.connect(token: token, catalog: ExerciseCatalog.titles(context))
            connected = true
            message = L("Xong. Thầy AI đã sẵn sàng.", "Done. The AI teacher is ready.")
        } catch {
            message = L("Không kết nối được: \(Friendly.message(error))", "Could not connect: \(Friendly.message(error))")
        }
    }
}
