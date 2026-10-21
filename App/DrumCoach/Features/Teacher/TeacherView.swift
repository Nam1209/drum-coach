import DrumAI
import SwiftData
import SwiftUI

/// Hub for the AI teacher: send the weekly report, sync plans back, apply them, read the latest advice.
struct TeacherView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Query(sort: \StoredReport.created, order: .reverse) private var reports: [StoredReport]
    @State private var working = false
    @State private var message: String?
    @State private var pending: StoredReport?
    @AppStorage("claude.model") private var model = ClaudeClient.defaultModel

    var body: some View {
        List {
            if !TeacherConnection.isConfigured {
                Section {
                    NavigationLink("Kết nối thầy AI (một lần)") { TeacherSetupView() }
                } footer: {
                    Text("Dùng gói Claude Pro của bạn qua Notion — không tốn thêm tiền.")
                }
            } else {
                Section {
                    Button { Task { await send() } } label: { Label("Gửi cho thầy (báo cáo tuần)", systemImage: "paperplane") }
                    Button { Task { await sync() } } label: { Label("Đồng bộ kế hoạch", systemImage: "arrow.triangle.2.circlepath") }
                    if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
                } footer: {
                    Text("Sau khi gửi: app Claude mở ra, lời nhắn đã được copy — dán vào Project \"Thầy dạy trống\" rồi gửi. Xong quay lại bấm Đồng bộ.")
                }
            }
            if let key = Keychain.get(Keychain.claudeKey), !key.isEmpty {
                Section {
                    Button { Task { await viaAPI(key) } } label: {
                        Label(working ? "Thầy đang phân tích…" : "Phân tích tự động bằng API (~$\(String(format: "%.2f", TeacherConnection.estimatedAPICost(context))))",
                              systemImage: "sparkles")
                    }
                    .disabled(working)
                } footer: {
                    Text("Dùng API key trong Cài đặt — không cần dán vào app Claude.")
                }
            }
            if let active = reports.first(where: { $0.appliedAt != nil }), let r = active.report {
                ReportSections(title: active.title, report: r)
            }
            if reports.contains(where: { $0.appliedAt == nil }) {
                Section("Kế hoạch mới chưa áp dụng") {
                    ForEach(reports.filter { $0.appliedAt == nil }) { s in Button(s.title) { pending = s } }
                }
            }
            Section("Các báo cáo trước") {
                ForEach(reports.filter { $0.appliedAt != nil }.dropFirst()) { s in
                    NavigationLink(s.title) { List { if let r = s.report { ReportSections(title: s.title, report: r) } }.navigationTitle(s.title) }
                }
            }
            Section {
                NavigationLink("Hỏi thầy (chat)") { TeacherChatView() }
                NavigationLink("Hồ sơ học viên") { ProfileEditor() }
                NavigationLink("Cài đặt kết nối") { TeacherSetupView() }
            }
        }
        .navigationTitle("Thầy AI")
        .sheet(item: $pending) { s in ApplyPlanView(stored: s, current: reports.first { $0.appliedAt != nil }) }
        .onChange(of: phase) { _, p in if p == .active, TeacherConnection.isConfigured { Task { await sync(quiet: true) } } }
    }

    private func send() async {
        working = true; defer { working = false }
        do { message = "Đã gửi \(try await TeacherConnection.sendWeekly(context)). Dán lời nhắn vào Claude nhé." }
        catch { message = "Không gửi được: \(error)" }
    }

    private func viaAPI(_ key: String) async {
        working = true; defer { working = false }
        do { pending = try await TeacherConnection.weeklyReportViaAPI(context, apiKey: key, model: model) }
        catch { message = "Claude chưa trả lời được: \(error). Kế hoạch cũ vẫn giữ nguyên." }
    }

    private func sync(quiet: Bool = false) async {
        do {
            let out = try await TeacherConnection.sync(context)
            if let first = out.plans.last { pending = first }
            if !quiet || !out.plans.isEmpty || out.exercises > 0 {
                message = "Kế hoạch mới: \(out.plans.count) · Bài tập mới: \(out.exercises)" + (out.problems.isEmpty ? "" : "\nLỗi: " + out.problems.joined(separator: "; "))
            }
        } catch {
            if !quiet { message = "Không đồng bộ được: \(error)" }
        }
    }
}

struct ReportSections: View {
    let title: String
    let report: TeacherReport

    var body: some View {
        Section("Tóm tắt · \(title)") { Text(report.summary) }
        if !report.progress.isEmpty { Section("Tiến bộ") { ForEach(report.progress, id: \.self) { Label($0, systemImage: "arrow.up.right").foregroundStyle(.green) } } }
        Section("3 điều cần sửa") { ForEach(Array(report.fixFirst.enumerated()), id: \.offset) { Text("\($0.offset + 1). \($0.element)") } }
        if !report.likelyCauses.isEmpty { Section("Nguyên nhân có thể") { ForEach(report.likelyCauses, id: \.self) { Text($0) } } }
        Section("Tài liệu") {
            ForEach(report.resources, id: \.self) { r in
                if let url = safeURL(r) {
                    Link(destination: url) {
                        VStack(alignment: .leading) {
                            Label(r.title, systemImage: r.kind == "youtube" ? "play.rectangle" : "book")
                            Text(r.why).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        Section("Mốc tiếp theo") { Text(report.nextCheckpoint) }
    }

    /// Only https links are opened; anything else falls back to a YouTube search for the resource.
    private func safeURL(_ r: Resource) -> URL? {
        if let u = r.url, u.scheme?.lowercased() == "https", u.host != nil { return u }
        let q = r.searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.youtube.com/results?search_query=\(q)")
    }
}

struct ApplyPlanView: View {
    let stored: StoredReport
    let current: StoredReport?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let r = stored.report {
                    Section("So với kế hoạch đang dùng") {
                        LabeledContent("Số ngày trong kế hoạch", value: "\(current?.report?.weekPlan.count ?? 0) → \(r.weekPlan.count)")
                        LabeledContent("Bài mới thầy soạn", value: "\(r.weekPlan.flatMap(\.allItems).filter { $0.newExerciseDSL != nil }.count)")
                    }
                    ReportSections(title: stored.title, report: r)
                }
            }
            .navigationTitle("Áp dụng kế hoạch mới?")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Để sau") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Áp dụng") { TeacherConnection.apply(stored, context); dismiss() } }
            }
        }
    }
}

struct ProfileEditor: View {
    @State private var profile = TeacherConnection.profile
    @State private var newNote = ""

    var body: some View {
        Form {
            Section("Mục tiêu") {
                TextField("Mục tiêu", text: $profile.goal)
                Stepper("Phút tập mỗi ngày: \(profile.minutesPerDay)", value: $profile.minutesPerDay, in: 10...180, step: 5)
            }
            Section("Ghi chú cho thầy") {
                ForEach(profile.notes, id: \.self) { Text($0) }.onDelete { profile.notes.remove(atOffsets: $0) }
                HStack {
                    TextField("Ví dụ: cổ tay trái yếu, tập buổi tối", text: $newNote)
                    Button("Thêm") { profile.notes.append(newNote); newNote = "" }.disabled(newNote.isEmpty)
                }
            }
            Section("Lời khuyên thầy đã dặn") {
                ForEach(profile.pastAdvice.reversed(), id: \.text) { a in
                    VStack(alignment: .leading) {
                        Text(a.text)
                        Text(a.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Hồ sơ học viên")
        .onChange(of: profile) { _, p in TeacherConnection.profile = p }
    }
}
