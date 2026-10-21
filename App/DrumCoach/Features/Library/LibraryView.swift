import DrumAudio
import DrumCore
import DrumLibrary
import SwiftData
import SwiftUI

struct LibraryView: View {
    let voiceBank: CountVoiceBank
    @Query(sort: \StoredExercise.createdAt, order: .reverse) private var mine: [StoredExercise]
    @Environment(\.modelContext) private var context
    @State private var stickLength = 8
    @State private var balancedOnly = false
    @State private var editing: StoredExercise?
    @State private var creating = false
    @State private var importing = false

    var body: some View {
        List {
            Section("Bài của tôi") {
                if mine.isEmpty { Text("Chưa có bài nào. Bấm + để soạn, hoặc nhập từ sách.").foregroundStyle(.secondary) }
                ForEach(mine) { item in
                    if let ex = item.exercise {
                        practiceLink(ex)
                            .swipeActions {
                                Button("Sửa") { editing = item }.tint(.orange)
                                Button("Xóa", role: .destructive) { context.delete(item) }
                            }
                    } else {
                        Text("\(item.title) (lỗi cú pháp)").foregroundStyle(.red)
                    }
                }
            }
            Section { NavigationLink("🎵 Chơi theo nhạc / backing track") { PlayAlongView() } }
            Section {
                ForEach(StarterExercises.all) { practiceLink($0) }
            } header: {
                Text("Khởi động")
            } footer: {
                Text("Nhấn giữ một groove để tạo các bài hoán vị kick hoặc snare.")
            }
            Section("40 rudiment chuẩn PAS") {
                NavigationLink("Xem 40 rudiment") { List(PASRudiments.all) { practiceLink($0) }.navigationTitle("PAS Rudiments") }
            }
            ForEach(Grade8Curriculum.units) { unit in
                Section(unit.title) {
                    ForEach(unit.exercises.compactMap { try? ExerciseDSL.parse($0) }) { ex in
                        practiceLink(withSource(ex, unit.skill))
                    }
                }
            }
            Section {
                Picker("Số nốt", selection: $stickLength) { Text("4").tag(4); Text("8").tag(8) }
                Toggle("Chỉ tổ hợp cân bằng (bằng số R và L)", isOn: $balancedOnly)
                NavigationLink("Xem danh sách tổ hợp") {
                    List(StickingGenerator.singleBeat(length: stickLength, subdivision: 2, balancedOnly: balancedOnly)) { practiceLink($0) }
                        .navigationTitle("Sticking \(stickLength) nốt")
                }
                NavigationLink("Đọc nhạc ngẫu nhiên") {
                    List(readingLines) { practiceLink($0) }
                    .navigationTitle("Đọc nhạc")
                }
            } header: {
                Text("Kiểu Stick Control (tự sinh)")
            } footer: {
                Text("Mỗi bài lặp 20 lần không dừng rồi mới sang bài kế tiếp, theo lời dặn của G. L. Stone.")
            }
        }
        .navigationTitle("Thư viện")
        .toolbar {
            Button { importing = true } label: { Label("Nhập PDF", systemImage: "doc.viewfinder") }
            Button { creating = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $importing) { NavigationStack { PDFImportView() } }
        .sheet(isPresented: $creating) { NavigationStack { ExerciseEditorView(item: nil) } }
        .sheet(item: $editing) { item in NavigationStack { ExerciseEditorView(item: item) } }
    }

    private var readingLines: [Exercise] {
        (1...30).map { (n: Int) -> Exercise in
            StickingGenerator.random(seed: UInt64(n), bars: 4, subdivision: n % 3 == 0 ? 4 : 2, rests: true)
        }
    }

    private func withSource(_ e: Exercise, _ s: String) -> Exercise { var x = e; x.source = s; return x }

    /// A row without the permutation menu (used inside permutation lists).
    private func plainLink(_ ex: Exercise) -> some View {
        NavigationLink {
            PracticeView(exercises: [ex], voiceBank: voiceBank)
        } label: {
            VStack(alignment: .leading) {
                Text(ex.title)
                Text("\(ex.timeSignature.beats)/\(ex.timeSignature.unit), \(ex.suggestedTempo.lowerBound)–\(ex.suggestedTempo.upperBound) BPM")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func practiceLink(_ ex: Exercise) -> some View {
        let isGroove = Set(ex.notes.map(\.voice)).isSuperset(of: [.kick, .snare])
        return NavigationLink {
            PracticeView(exercises: [ex], voiceBank: voiceBank)
                .navigationTitle(ex.title).navigationBarTitleDisplayMode(.inline)
        } label: {
            VStack(alignment: .leading) {
                Text(ex.title)
                Text("\(ex.timeSignature.beats)/\(ex.timeSignature.unit), \(ex.suggestedTempo.lowerBound)–\(ex.suggestedTempo.upperBound) BPM")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            if isGroove {
                NavigationLink("Hoán vị kick") { List(StickingGenerator.kickPermutations(ex)) { plainLink($0) }.navigationTitle("Hoán vị kick") }
                NavigationLink("Hoán vị snare (nốt ma)") { List(StickingGenerator.snarePermutations(ex)) { plainLink($0) }.navigationTitle("Hoán vị snare") }
            }
        }
    }
}
