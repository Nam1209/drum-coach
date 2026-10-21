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
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(title: "Thầy AI", subtitle: "Claude Pro qua Notion: gửi lịch sử, thầy lên kế hoạch, app đồng bộ về") {
                    if TeacherConnection.isConfigured {
                        HStack(spacing: 10) {
                            Button { Task { await send() } } label: { Label("Gửi cho thầy", systemImage: "paperplane") }
                                .buttonStyle(.bordered)
                            Button { Task { await sync() } } label: { Label("Đồng bộ", systemImage: "arrow.triangle.2.circlepath") }
                                .buttonStyle(.borderedProminent)
                        }
                        .disabled(working)
                    }
                }
                if !TeacherConnection.isConfigured {
                    CardSection(footer: "Dùng gói Claude Pro của bạn qua Notion, không tốn thêm tiền.") {
                        CardLink("Kết nối thầy AI (một lần)", subtitle: "Hướng dẫn từng bước, khoảng 5 phút") { TeacherSetupView() }
                    }
                } else {
                    Stage {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(working ? "Đang làm việc với Notion…" : "Đã kết nối Notion", systemImage: "circle.fill")
                                .labelStyle(StatusDot(color: working ? Theme.offTime : Theme.onTime))
                            if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
                            Text("Sau khi gửi: app Claude mở ra, lời nhắn đã được copy. Dán vào Project \"Thầy dạy trống\" rồi gửi, xong quay lại bấm Đồng bộ.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let key = Keychain.get(Keychain.claudeKey), !key.isEmpty {
                    CardSection(footer: "Dùng API key trong Cài đặt, không cần dán vào app Claude.") {
                        CardButton(working ? "Thầy đang phân tích…" : "Phân tích tự động bằng API (khoảng \(String(format: "%.2f", TeacherConnection.estimatedAPICost(context))) USD)",
                                   systemImage: "sparkles") { Task { await viaAPI(key) } }
                            .disabled(working)
                    }
                }
                PracticeForecastSections()
                HStack(alignment: .top, spacing: 22) {
                    VStack(spacing: 22) {
                        if let active = reports.first(where: { $0.appliedAt != nil }), let r = active.report {
                            ReportSections(title: active.title, report: r)
                        } else {
                            CardSection("Kế hoạch của thầy") {
                                Text("Chưa có kế hoạch. Gửi lịch sử cho thầy rồi bấm Đồng bộ để nhận kế hoạch tuần.").foregroundStyle(.secondary)
                            }
                        }
                    }
                    VStack(spacing: 22) {
                        CardSection("Trò chuyện và hồ sơ") {
                            CardLink("Hỏi thầy", subtitle: "Hỏi về kỹ thuật, bài tập, kế hoạch") { TeacherChatView() }
                            CardLink("Hồ sơ học viên", subtitle: "Mục tiêu, phút tập mỗi ngày, ghi chú cho thầy") { ProfileEditor() }
                            CardLink("Cài đặt kết nối") { TeacherSetupView() }
                        }
                        let fresh = reports.filter { $0.appliedAt == nil }
                        if !fresh.isEmpty {
                            CardSection("Kế hoạch mới chưa áp dụng") {
                                ForEach(fresh) { s in CardButton(s.title, systemImage: "tray.and.arrow.down") { pending = s } }
                            }
                        }
                        let older = Array(reports.filter { $0.appliedAt != nil }.dropFirst())
                        if !older.isEmpty {
                            CardSection("Các báo cáo trước") {
                                ForEach(older) { s in
                                    CardLink(s.title) {
                                        ScrollView { if let r = s.report { ReportSections(title: s.title, report: r).padding(Theme.pagePadding) } }
                                            .background(Theme.canvas).navigationTitle(s.title)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.canvas)
        .sheet(item: $pending) { s in ApplyPlanView(stored: s, current: reports.first { $0.appliedAt != nil }) }
        .onChange(of: phase) { _, p in if p == .active, TeacherConnection.isConfigured { Task { await sync(quiet: true) } } }
    }

    private func send() async {
        working = true; defer { working = false }
        do { message = "Đã gửi \(try await TeacherConnection.sendWeekly(context)). Dán lời nhắn vào Claude nhé." }
        catch { message = "Không gửi được: \(Friendly.message(error))" }
    }

    private func viaAPI(_ key: String) async {
        working = true; defer { working = false }
        do { pending = try await TeacherConnection.weeklyReportViaAPI(context, apiKey: key, model: model) }
        catch { message = "\(Friendly.message(error)) Kế hoạch cũ vẫn giữ nguyên." }
    }

    private func sync(quiet: Bool = false) async {
        working = true; defer { working = false }
        do {
            let out = try await TeacherConnection.sync(context)
            if let first = out.plans.last { pending = first }
            if !quiet || !out.plans.isEmpty || out.exercises > 0 {
                message = "Kế hoạch mới: \(out.plans.count) · Bài tập mới: \(out.exercises)" + (out.problems.isEmpty ? "" : "\n" + out.problems.joined(separator: "\n"))
            }
        } catch {
            if !quiet { message = "Không đồng bộ được: \(Friendly.message(error))" }
        }
    }
}

struct ReportSections: View {
    let title: String
    let report: TeacherReport

    var body: some View {
        VStack(spacing: 22) {
            CardSection("Kế hoạch đang áp dụng", trailing: title) {
                Text(report.summary)
                ForEach(report.progress, id: \.self) { Label($0, systemImage: "arrow.up.right").foregroundStyle(Theme.onTime) }
            }
            CardSection("Ba điều cần sửa trước") {
                ForEach(Array(report.fixFirst.enumerated()), id: \.offset) { k, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(k + 1)").font(Theme.number(17)).foregroundStyle(Theme.shell)
                        Text(item)
                    }
                }
            }
            if !report.likelyCauses.isEmpty {
                CardSection("Nguyên nhân có thể") { ForEach(report.likelyCauses, id: \.self) { Text($0) } }
            }
            if !report.resources.isEmpty {
                CardSection("Tài liệu thầy gợi ý") {
                    ForEach(report.resources, id: \.self) { r in
                        if let url = safeURL(r) {
                            Link(destination: url) {
                                HStack(spacing: 14) {
                                    Image(systemName: r.kind == "youtube" ? "play.rectangle.fill" : "book.fill").font(.title2).foregroundStyle(Theme.shell)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(r.title).foregroundStyle(.primary)
                                        Text(r.why).font(.footnote).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            CardSection("Mốc tiếp theo") { Text(report.nextCheckpoint) }
        }
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
                Stepper("Phút tập mỗi ngày: \(profile.minutesPerDay)", value: $profile.minutesPerDay, in: 10...240, step: 5)
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

/// A small coloured dot before the label (connection status).
private struct StatusDot: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            configuration.title.font(.headline)
        }
    }
}
