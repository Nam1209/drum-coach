import DrumAI
import DrumCore
import SwiftData
import SwiftUI

/// Ask the teacher anything (API key required; without one, chat inside the Claude Project).
struct TeacherChatView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("claude.model") private var model = ClaudeClient.defaultModel
    @State private var chat: TeacherChat?
    @State private var messages: [(role: String, text: String)] = []
    @State private var input = ""
    @State private var waiting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, m in
                        Text(m.text)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(m.role == "user" ? Color.orange.opacity(0.18) : Color(.secondarySystemBackground)))
                            .frame(maxWidth: .infinity, alignment: m.role == "user" ? .trailing : .leading)
                    }
                    if waiting { ProgressView() }
                    if let error { Text(error).foregroundStyle(.red) }
                }
                .padding()
            }
            HStack {
                TextField(L("Hỏi thầy, ví dụ: tại sao tôi hay trễ ở \"&\"?", "Ask the teacher, e.g. why am I often late on the \"&\"?"), text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button(L("Gửi", "Send")) { Task { await send() } }.disabled(input.isEmpty || waiting)
            }
            .padding()
        }
        .navigationTitle(L("Hỏi thầy", "Ask the teacher"))
    }

    private func send() async {
        guard let key = Keychain.get(Keychain.claudeKey), !key.isEmpty else { error = L("Cần API key trong Cài đặt (hoặc hỏi thầy trong Project trên Claude).", "You need an API key in Settings (or ask the teacher in the Project on Claude)."); return }
        if chat == nil {
            let active = (try? context.fetch(FetchDescriptor<StoredReport>(sortBy: [SortDescriptor(\.created, order: .reverse)])))?
                .first { $0.appliedAt != nil }?.report
            chat = TeacherChat(client: ClaudeClient(apiKey: key, model: model), digest: HistoryStore.digest(context),
                               profile: TeacherConnection.profile, lastReport: active)
        }
        let q = input
        input = ""
        messages.append((role: "user", text: q))
        waiting = true; defer { waiting = false }
        do {
            var c = chat!
            let a = try await c.ask(q)
            chat = c
            messages.append((role: "assistant", text: a))
            error = nil
        } catch {
            self.error = Friendly.message(error)
        }
    }
}
