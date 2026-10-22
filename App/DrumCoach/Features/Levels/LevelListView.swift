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
        return LevelProgress(bestScores: best, levels: levels, reached: SettingsStore.levelHistory.map(\.0).max() ?? 0)
    }

    private let levels = BookLibrary.levels.sorted { $0.id < $1.id }
    private let books = BookLibrary.load()

    var body: some View {
        let p = progress
        let shown = levels.first { $0.id == (selected ?? min(8, p.currentLevel + 1)) } ?? levels.first
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(title: L("Cấp độ", "Levels"), subtitle: L("Đạt một bài khi trên 90%. Đạt mọi bài thì lên cấp.", "Pass an exercise by scoring above 90%. Pass them all to level up."))
                if p.bestScores.isEmpty {
                    Label(L("Lần đầu bạn được thử mọi cấp để tìm điểm bắt đầu. Gợi ý: bắt đầu từ Grade 1.", "The first time, you can try any level to find your starting point. Tip: start with Grade 1."), systemImage: "flag")
                        .font(.callout).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    ForEach(levels) { level in gradeCard(level, p, isSelected: level.id == shown?.id) }
                }
                let missing = PrivateLibraryLoader.missingGrades(available: books.map(\.grade), current: p.currentLevel)
                if !missing.isEmpty {
                    Label(L("Thêm sách Rockschool Grade \(missing.map(String.init).joined(separator: ", ")) để có bài kiểm tra đúng sách cho các cấp tiếp theo.", "Add the Rockschool Grade \(missing.map(String.init).joined(separator: ", ")) book to get the real tests for the next levels."),
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
        .alert(L("Chúc mừng! Bạn đã đạt Grade \(celebrate ?? 0)", "Congratulations! You reached Grade \(celebrate ?? 0)"), isPresented: Binding(get: { celebrate != nil }, set: { if !$0 { celebrate = nil } })) {
            Button(L("Tuyệt", "Great")) { celebrate = nil }
        }
    }

    // MARK: Cards

    private func gradeCard(_ level: Level, _ p: LevelProgress, isSelected: Bool) -> some View {
        let passed = level.tests.filter(p.isPassed).count
        let done = p.isPassed(level), open = p.isUnlocked(level)
        let fraction = level.tests.isEmpty ? 0 : Double(passed) / Double(level.tests.count)
        let status = done ? L("Đã đạt", "Passed") : !open ? L("Chưa mở", "Locked") : level.tests.isEmpty ? L("Chưa có bài", "No exercises") : L("\(passed)/\(level.tests.count) bài đạt", "\(passed)/\(level.tests.count) passed")
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
                Text(L("Bài kiểm tra Grade \(level.id)", "Grade \(level.id) tests")).font(.title3.weight(.semibold))
                Spacer()
                Text(L("\(level.tests.filter(p.isPassed).count)/\(level.tests.count) đạt", "\(level.tests.filter(p.isPassed).count)/\(level.tests.count) passed")).font(Theme.number(15, weight: .medium)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                if level.tests.isEmpty { Text(L("Chưa có bài cho cấp này.", "No exercises for this level yet.")).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading) }
                ForEach(Array(level.tests.enumerated()), id: \.element.id) { k, item in
                    if let ex = try? ExerciseDSL.parse(item.dsl) {
                        NavigationLink {
                            PracticeView(exercises: [ex], voiceBank: voiceBank, testItem: item)
                                .navigationTitle(ex.title).navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ExerciseTitle.short(ex.title, showingGrade: false)).foregroundStyle(.primary)
                                    Text(L("\(Int(item.bpm)) BPM, \(Int(item.duration)) giây", "\(Int(item.bpm)) BPM, \(Int(item.duration)) sec")).font(.footnote).foregroundStyle(.secondary)
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

    private func scoreTag(_ score: Double?, passed: Bool) -> some View {
        Text(score.map { "\(Int($0.rounded()))%" } ?? L("chưa thử", "not tried"))
            .font(Theme.number(13, weight: .medium))
            .foregroundStyle(passed ? Theme.onTime : .secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(passed ? Theme.onTime.opacity(0.14) : Theme.hairline))
    }

    private func skills(_ p: LevelProgress) -> some View {
        let grade = max(1, p.currentLevel + 1)
        let rows: [(String, String, AnyView)] = [
            (L("Nghe chép nhịp", "Rhythm dictation"), L("Nghe 2 ô nhịp, chạm vào ô có tiếng trống", "Listen to 2 bars, tap the cells where you hear a drum"), AnyView(DictationView())),
            ("Ear test", L("Nghe rồi đánh lại, như phần thi Rockschool", "Listen and play it back, like the Rockschool exam"), AnyView(EarTestView(grade: grade))),
            (L("Câu hỏi kiến thức (GMQ)", "Knowledge questions (GMQ)"), L("Nhạc lý và tên bộ trống theo Grade \(grade)", "Music theory and drum kit names for Grade \(grade)"), AnyView(GMQuizView(grade: grade))),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            Text(L("Kỹ năng nghe", "Listening skills")).font(.title3.weight(.semibold))
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
