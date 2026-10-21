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

    private var progress: LevelProgress {
        var best: [String: Double] = [:]
        for a in attempts { if let id = a.levelTestId { best[id] = max(best[id] ?? 0, a.score) } }
        return LevelProgress(bestScores: best, levels: levels)
    }

    private let levels = BookLibrary.levels
    private let books = BookLibrary.load()

    var body: some View {
        let p = progress
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Level hiện tại").foregroundStyle(.secondary)
                        Text(p.currentLevel == 0 ? "Chưa xếp level" : "Level \(p.currentLevel)").font(.largeTitle.bold())
                    }
                    Spacer()
                    Text("Đạt khi mọi bài > 90%").font(.callout).foregroundStyle(.secondary)
                }
                if p.bestScores.isEmpty {
                    Text("Lần đầu: bạn được thử bất kỳ level nào để tìm điểm bắt đầu. Gợi ý: bắt đầu từ Level 1.")
                        .font(.callout)
                }
            }
            let missing = PrivateLibraryLoader.missingGrades(available: books.map(\.grade), current: p.currentLevel)
            if !missing.isEmpty {
                Section {
                    Label("Hãy upload sách Rockschool Grade \(missing.map(String.init).joined(separator: ", ")) để có bài test đúng sách cho các level tiếp theo.",
                          systemImage: "book.closed").foregroundStyle(.orange)
                }
            }
            Section("Luyện các phần thi khác") {
                NavigationLink("Ear Test (nghe rồi đánh lại)") { EarTestView(grade: max(1, p.currentLevel + 1)) }
                NavigationLink("Nghe chép nhịp") { DictationView() }
                NavigationLink("Câu hỏi kiến thức (GMQ)") { GMQuizView(grade: max(1, p.currentLevel + 1)) }
            }
            ForEach(levels) { level in
                Section {
                    ForEach(level.tests) { item in
                        if let ex = try? ExerciseDSL.parse(item.dsl) {
                            NavigationLink {
                                PracticeView(exercises: [ex], voiceBank: voiceBank, testItem: item)
                                    .navigationTitle("Test · \(ex.title)").navigationBarTitleDisplayMode(.inline)
                            } label: {
                                HStack {
                                    Image(systemName: p.isPassed(item) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(p.isPassed(item) ? .green : .secondary)
                                    Text(ex.title)
                                    Text("♩=\(Int(item.bpm))").foregroundStyle(.secondary)
                                    Spacer()
                                    Text(p.bestScores[item.id].map { "\(Int($0.rounded()))%" } ?? "–").monospacedDigit()
                                }
                            }
                            .disabled(!p.isUnlocked(level))
                        }
                    }
                } header: {
                    HStack {
                        Text(level.title)
                        Spacer()
                        Text(p.isPassed(level) ? "✅" : p.isUnlocked(level) ? "đang làm" : "🔒")
                    }
                }
            }
        }
        .navigationTitle("Level")
        .onChange(of: p.currentLevel, initial: true) { old, new in
            if new > SettingsStore.currentGrade, new > 0, old != new { celebrate = new }
            SettingsStore.currentGrade = new
            if new > 0 { for l in 1...new { SettingsStore.markLevelReached(l) } }
        }
        .alert("Chúc mừng! Bạn đã đạt Level \(celebrate ?? 0) 🎉", isPresented: Binding(get: { celebrate != nil }, set: { if !$0 { celebrate = nil } })) {
            Button("Tuyệt") { celebrate = nil }
        }
    }
}
