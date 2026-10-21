import DrumAI
import DrumCore
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
                PageHeader(title: L("Thầy AI", "AI teacher"), subtitle: L("Claude Pro qua Notion: gửi lịch sử, thầy lên kế hoạch, app đồng bộ về", "Claude Pro via Notion: send your history, the teacher plans, the app syncs it back")) {
                    if TeacherConnection.isConfigured {
                        HStack(spacing: 10) {
                            Button { Task { await send() } } label: { Label(L("Gửi cho thầy", "Send to teacher"), systemImage: "paperplane") }
                                .buttonStyle(.bordered)
                            Button { Task { await sync() } } label: { Label(L("Đồng bộ", "Sync"), systemImage: "arrow.triangle.2.circlepath") }
                                .buttonStyle(.borderedProminent)
                        }
                        .disabled(working)
                    }
                }
                if !TeacherConnection.isConfigured {
                    CardSection(footer: L("Dùng gói Claude Pro của bạn qua Notion, không tốn thêm tiền.", "Use your Claude Pro plan through Notion at no extra cost.")) {
                        CardLink(L("Kết nối thầy AI (một lần)", "Connect the AI teacher (one time)"), subtitle: L("Dán 1 mã từ Notion, khoảng 2 phút", "Paste one key from Notion, about 2 minutes")) { TeacherSetupView() }
                    }
                } else {
                    Stage {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(working ? L("Đang làm việc với Notion…", "Working with Notion…") : L("Đã kết nối Notion", "Notion connected"), systemImage: "circle.fill")
                                .labelStyle(StatusDot(color: working ? Theme.offTime : Theme.onTime))
                            if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
                            Text(L("Sau khi gửi: app Claude mở ra, lời nhắn đã được copy. Dán vào Project \"Thầy dạy trống\" rồi gửi, xong quay lại bấm Đồng bộ.", "After sending, the Claude app opens and the message is copied. Paste it into the \"Thầy dạy trống\" Project and send it, then come back and tap Sync."))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let key = Keychain.get(Keychain.claudeKey), !key.isEmpty {
                    CardSection(footer: L("Dùng API key trong Cài đặt, không cần dán vào app Claude.", "Uses the API key from Settings, no need to paste into the Claude app.")) {
                        CardButton(working ? L("Thầy đang phân tích…", "Teacher is analyzing…") : L("Phân tích tự động bằng API (khoảng \(String(format: "%.2f", TeacherConnection.estimatedAPICost(context))) USD)", "Analyze automatically via API (about \(String(format: "%.2f", TeacherConnection.estimatedAPICost(context))) USD)"),
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
                            CardSection(L("Kế hoạch của thầy", "Teacher's plan")) {
                                Text(L("Chưa có kế hoạch. Gửi lịch sử cho thầy rồi bấm Đồng bộ để nhận kế hoạch tuần.", "No plan yet. Send your history to the teacher, then tap Sync to get a weekly plan.")).foregroundStyle(.secondary)
                            }
                        }
                    }
                    VStack(spacing: 22) {
                        CardSection(L("Trò chuyện và hồ sơ", "Chat and profile")) {
                            CardLink(L("Hỏi thầy", "Ask the teacher"), subtitle: L("Hỏi về kỹ thuật, bài tập, kế hoạch", "Ask about technique, exercises, the plan")) { TeacherChatView() }
                            CardLink(L("Hồ sơ học viên", "Student profile"), subtitle: L("Mục tiêu, phút tập mỗi ngày, ghi chú cho thầy", "Goal, daily minutes, notes for the teacher")) { ProfileEditor() }
                            CardLink(L("Cài đặt kết nối", "Connection settings")) { TeacherSetupView() }
                        }
                        let fresh = reports.filter { $0.appliedAt == nil }
                        if !fresh.isEmpty {
                            CardSection(L("Kế hoạch mới chưa áp dụng", "New plans not applied yet")) {
                                ForEach(fresh) { s in CardButton(s.title, systemImage: "tray.and.arrow.down") { pending = s } }
                            }
                        }
                        let older = Array(reports.filter { $0.appliedAt != nil }.dropFirst())
                        if !older.isEmpty {
                            CardSection(L("Các báo cáo trước", "Earlier reports")) {
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
        do { message = L("Đã gửi \(try await TeacherConnection.sendWeekly(context)). Dán lời nhắn vào Claude nhé.", "Sent \(try await TeacherConnection.sendWeekly(context)). Paste the message into Claude.") }
        catch { message = L("Không gửi được: \(Friendly.message(error))", "Could not send: \(Friendly.message(error))") }
    }

    private func viaAPI(_ key: String) async {
        working = true; defer { working = false }
        do { pending = try await TeacherConnection.weeklyReportViaAPI(context, apiKey: key, model: model) }
        catch { message = L("\(Friendly.message(error)) Kế hoạch cũ vẫn giữ nguyên.", "\(Friendly.message(error)) Your old plan is unchanged.") }
    }

    private func sync(quiet: Bool = false) async {
        working = true; defer { working = false }
        do {
            let out = try await TeacherConnection.sync(context)
            if let first = out.plans.last { pending = first }
            if !quiet || !out.plans.isEmpty || out.exercises > 0 {
                message = L("Kế hoạch mới: \(out.plans.count) · Bài tập mới: \(out.exercises)", "New plans: \(out.plans.count) · New exercises: \(out.exercises)") + (out.problems.isEmpty ? "" : "\n" + out.problems.joined(separator: "\n"))
            }
        } catch {
            if !quiet { message = L("Không đồng bộ được: \(Friendly.message(error))", "Could not sync: \(Friendly.message(error))") }
        }
    }
}

struct ReportSections: View {
    let title: String
    let report: TeacherReport

    var body: some View {
        VStack(spacing: 22) {
            CardSection(L("Kế hoạch đang áp dụng", "Current plan"), trailing: title) {
                Text(report.summary)
                ForEach(report.progress, id: \.self) { Label($0, systemImage: "arrow.up.right").foregroundStyle(Theme.onTime) }
            }
            CardSection(L("Ba điều cần sửa trước", "Three things to fix first")) {
                ForEach(Array(report.fixFirst.enumerated()), id: \.offset) { k, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(k + 1)").font(Theme.number(17)).foregroundStyle(Theme.shell)
                        Text(item)
                    }
                }
            }
            if !report.likelyCauses.isEmpty {
                CardSection(L("Nguyên nhân có thể", "Likely causes")) { ForEach(report.likelyCauses, id: \.self) { Text($0) } }
            }
            if !report.resources.isEmpty {
                CardSection(L("Tài liệu thầy gợi ý", "Resources the teacher suggests")) {
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
            CardSection(L("Mốc tiếp theo", "Next checkpoint")) { Text(report.nextCheckpoint) }
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
                    Section(L("So với kế hoạch đang dùng", "Compared with the current plan")) {
                        LabeledContent(L("Số ngày trong kế hoạch", "Days in the plan"), value: "\(current?.report?.weekPlan.count ?? 0) → \(r.weekPlan.count)")
                        LabeledContent(L("Bài mới thầy soạn", "New exercises from the teacher"), value: "\(r.weekPlan.flatMap(\.allItems).filter { $0.newExerciseDSL != nil }.count)")
                    }
                    ReportSections(title: stored.title, report: r)
                }
            }
            .navigationTitle(L("Áp dụng kế hoạch mới?", "Apply the new plan?"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Để sau", "Later")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L("Áp dụng", "Apply")) { TeacherConnection.apply(stored, context); dismiss() } }
            }
        }
    }
}

struct ProfileEditor: View {
    @State private var profile = TeacherConnection.profile
    @State private var newNote = ""

    var body: some View {
        Form {
            Section(L("Mục tiêu", "Goal")) {
                TextField(L("Mục tiêu", "Goal"), text: $profile.goal)
                Stepper(L("Phút tập mỗi ngày: \(profile.minutesPerDay)", "Minutes per day: \(profile.minutesPerDay)"), value: $profile.minutesPerDay, in: 10...240, step: 5)
            }
            Section(L("Ghi chú cho thầy", "Notes for the teacher")) {
                ForEach(profile.notes, id: \.self) { Text($0) }.onDelete { profile.notes.remove(atOffsets: $0) }
                HStack {
                    TextField(L("Ví dụ: cổ tay trái yếu, tập buổi tối", "Example: weak left wrist, practice in the evening"), text: $newNote)
                    Button(L("Thêm", "Add")) { profile.notes.append(newNote); newNote = "" }.disabled(newNote.isEmpty)
                }
            }
            Section(L("Lời khuyên thầy đã dặn", "Advice from the teacher")) {
                ForEach(profile.pastAdvice.reversed(), id: \.text) { a in
                    VStack(alignment: .leading) {
                        Text(a.text)
                        Text(a.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(L("Hồ sơ học viên", "Student profile"))
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
