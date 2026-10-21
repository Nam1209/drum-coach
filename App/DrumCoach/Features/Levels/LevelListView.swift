import DrumAudio
import DrumCore
import DrumLibrary
import SwiftData
import SwiftUI

/// The 8 levels (one per Rockschool grade). A test passes above 90%; a level passes when all its tests pass.
struct LevelListView: View {
    let voiceBank: CountVoiceBank
    @Query(filter: #Predicate<PracticeSession> { $0.isLevelTest }) private var attempts: [PracticeSession]
    @State private var celebrate: Int?
    @State private var selected: Int?

    private var progress: LevelProgress {
        var best: [String: Double] = [:]
        for a in attempts { if let id = a.levelTestId { best[id] = max(best[id] ?? 0, a.score) } }
        return LevelProgress(bestScores: best, levels: levels)
    }

    private let levels = BookLibrary.levels.sorted { $0.id < $1.id }
    private let books = BookLibrary.load()

    var body: some View {
        let p = progress
        let shown = levels.first { $0.id == (selected ?? min(8, p.currentLevel + 1)) } ?? levels.first
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(title: "Cấp độ", subtitle: "Đạt một bài khi trên 90%. Đạt mọi bài thì lên cấp.")
                if p.bestScores.isEmpty {
                    Label("Lần đầu bạn được thử mọi cấp để tìm điểm bắt đầu. Gợi ý: bắt đầu từ Grade 1.", systemImage: "flag")
                        .font(.callout).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    ForEach(levels) { level in gradeCard(level, p, isSelected: level.id == shown?.id) }
                }
                let missing = PrivateLibraryLoader.missingGrades(available: books.map(\.grade), current: p.currentLevel)
                if !missing.isEmpty {
                    Label("Thêm sách Rockschool Grade \(missing.map(String.init).joined(separator: ", ")) để có bài kiểm tra đúng sách cho các cấp tiếp theo.",
                          systemImage: "book.closed")
                        .font(.callout).foregroundStyle(Theme.offTime)
                }
                HStack(alignment: .top, spacing: 22) {
                    if let shown { testList(shown, p) }
                    skills(p)
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.canvas)
        .onChange(of: p.currentLevel, initial: true) { old, new in
            if new > SettingsStore.currentGrade, new > 0, old != new { celebrate = new }
            SettingsStore.currentGrade = new
            if new > 0 { for l in 1...new { SettingsStore.markLevelReached(l) } }
        }
        .alert("Chúc mừng! Bạn đã đạt Grade \(celebrate ?? 0)", isPresented: Binding(get: { celebrate != nil }, set: { if !$0 { celebrate = nil } })) {
            Button("Tuyệt") { celebrate = nil }
        }
    }

    // MARK: Cards

    private func gradeCard(_ level: Level, _ p: LevelProgress, isSelected: Bool) -> some View {
        let passed = level.tests.filter(p.isPassed).count
        let done = p.isPassed(level), open = p.isUnlocked(level)
        let fraction = level.tests.isEmpty ? 0 : Double(passed) / Double(level.tests.count)
        let status = done ? "Đã đạt" : !open ? "Chưa mở" : level.tests.isEmpty ? "Chưa có bài" : "\(passed)/\(level.tests.count) bài đạt"
        return Button { selected = level.id } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Grade").font(.footnote).foregroundStyle(.secondary)
                Text("\(level.id)").font(Theme.number(34)).foregroundStyle(done ? Theme.onTime : .primary)
                ProgressView(value: done ? 1 : fraction).tint(done ? Theme.onTime : Theme.shell)
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.stage))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.shell, lineWidth: isSelected ? 2 : 0))
            .opacity(open ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Grade \(level.id), \(status)")
    }

    private func testList(_ level: Level, _ p: LevelProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bài kiểm tra Grade \(level.id)").font(.title3.weight(.semibold))
                Spacer()
                Text("\(level.tests.filter(p.isPassed).count)/\(level.tests.count) đạt").font(Theme.number(15, weight: .medium)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                if level.tests.isEmpty { Text("Chưa có bài cho cấp này.").foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading) }
                ForEach(Array(level.tests.enumerated()), id: \.element.id) { k, item in
                    if let ex = try? ExerciseDSL.parse(item.dsl) {
                        NavigationLink {
                            PracticeView(exercises: [ex], voiceBank: voiceBank, testItem: item)
                                .navigationTitle(ex.title).navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(shortTitle(ex.title, grade: level.id)).foregroundStyle(.primary)
                                    Text("\(Int(item.bpm)) BPM, \(Int(item.duration)) giây").font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                scoreTag(p.bestScores[item.id], passed: p.isPassed(item))
                                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!p.isUnlocked(level))
                        if k < level.tests.count - 1 { Divider().padding(.leading, 18) }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.stage))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// "Grade 3 · Nhóm A · Đánh đơn" → "Nhóm A: Đánh đơn" (the grade is already in the heading).
    private func shortTitle(_ title: String, grade: Int) -> String {
        var parts = title.components(separatedBy: " · ")
        if parts.first == "Grade \(grade)" { parts.removeFirst() }
        guard parts.count > 1 else { return parts.joined() }
        return parts[0] + ": " + parts.dropFirst().joined(separator: ", ")
    }

    private func scoreTag(_ score: Double?, passed: Bool) -> some View {
        Text(score.map { "\(Int($0.rounded()))%" } ?? "chưa thử")
            .font(Theme.number(13, weight: .medium))
            .foregroundStyle(passed ? Theme.onTime : .secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(passed ? Theme.onTime.opacity(0.14) : Theme.hairline))
    }

    private func skills(_ p: LevelProgress) -> some View {
        let grade = max(1, p.currentLevel + 1)
        let rows: [(String, String, AnyView)] = [
            ("Nghe chép nhịp", "Nghe 2 ô nhịp, chạm vào ô có tiếng trống", AnyView(DictationView())),
            ("Ear test", "Nghe rồi đánh lại, như phần thi Rockschool", AnyView(EarTestView(grade: grade))),
            ("Câu hỏi kiến thức (GMQ)", "Nhạc lý và tên bộ trống theo Grade \(grade)", AnyView(GMQuizView(grade: grade))),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Kỹ năng nghe").font(.title3.weight(.semibold))
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { k, r in
                    NavigationLink { r.2 } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.0).foregroundStyle(.primary)
                                Text(r.1).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if k < rows.count - 1 { Divider().padding(.leading, 18) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.stage))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
