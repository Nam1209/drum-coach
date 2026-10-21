import DrumAudio
import DrumCore
import DrumLibrary
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    let voiceBank: CountVoiceBank
    @Query(sort: \StoredExercise.createdAt, order: .reverse) private var mine: [StoredExercise]
    @Environment(\.modelContext) private var context
    @State private var stickLength = 8
    @State private var balancedOnly = false
    @State private var editing: StoredExercise?
    @State private var creating = false
    @State private var importing = false
    @State private var importingMIDI = false
    @State private var midiMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(title: "Thư viện") {
                    HStack(spacing: 8) {
                        Button { importingMIDI = true } label: { Label("Nhập MIDI", systemImage: "pianokeys") }.buttonStyle(.bordered)
                        Button { importing = true } label: { Label("Nhập PDF", systemImage: "doc.viewfinder") }.buttonStyle(.bordered)
                        Button { creating = true } label: { Label("Soạn bài", systemImage: "plus") }.buttonStyle(.borderedProminent)
                    }
                }
                CardSection("Bài của tôi", footer: midiMessage ?? (mine.isEmpty ? nil : "Nhấn giữ một bài để sửa hoặc xóa.")) {
                    if mine.isEmpty { Text("Chưa có bài nào. Soạn bài mới, nhập từ sách PDF hoặc từ file MIDI.").foregroundStyle(.secondary) }
                    ForEach(mine) { item in
                        if let ex = item.exercise {
                            practiceLink(ex)
                                .contextMenu {
                                    Button("Sửa", systemImage: "pencil") { editing = item }
                                    Button("Xóa", systemImage: "trash", role: .destructive) { context.delete(item) }
                                }
                        } else {
                            Text("\(item.title) (lỗi cú pháp)").foregroundStyle(Theme.missed)
                                .contextMenu { Button("Xóa", systemImage: "trash", role: .destructive) { context.delete(item) } }
                        }
                    }
                    CardLink("Chơi theo nhạc", subtitle: "Mở một bài hát hoặc backing track rồi chơi theo") { PlayAlongView() }
                }
                CardSection("Khởi động", footer: "Nhấn giữ một groove để tạo các bài hoán vị kick hoặc snare.") {
                    ForEach(StarterExercises.all) { practiceLink($0) }
                }
                HStack(alignment: .top, spacing: 22) {
                    CardSection("Rudiment") {
                        CardLink("40 rudiment chuẩn PAS", value: "\(PASRudiments.all.count)") { ExerciseListPage(title: "40 rudiment chuẩn PAS", exercises: PASRudiments.all, voiceBank: voiceBank) }
                    }
                    CardSection("Kiểu Stick Control (tự sinh)", footer: "Mỗi bài lặp 20 lần không dừng rồi mới sang bài kế tiếp, theo lời dặn của G. L. Stone.") {
                        LabeledContent("Số nốt") {
                            Picker("Số nốt", selection: $stickLength) { Text("4").tag(4); Text("8").tag(8) }.pickerStyle(.segmented).frame(width: 140)
                        }
                        Toggle("Chỉ tổ hợp cân bằng (số R bằng số L)", isOn: $balancedOnly)
                        CardLink("Danh sách tổ hợp") {
                            ExerciseListPage(title: "Sticking \(stickLength) nốt",
                                             exercises: StickingGenerator.singleBeat(length: stickLength, subdivision: 2, balancedOnly: balancedOnly), voiceBank: voiceBank)
                        }
                        CardLink("Đọc nhạc ngẫu nhiên", value: "30 bài") { ExerciseListPage(title: "Đọc nhạc", exercises: readingLines, voiceBank: voiceBank) }
                    }
                }
                ForEach(Grade8Curriculum.units) { unit in
                    CardSection(unit.title) {
                        ForEach(unit.exercises.compactMap { try? ExerciseDSL.parse($0) }) { ex in
                            practiceLink(withSource(ex, unit.skill))
                        }
                    }
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.canvas)
        .fileImporter(isPresented: $importingMIDI, allowedContentTypes: [.midi]) { result in importMIDI(result) }
        .sheet(isPresented: $importing) { NavigationStack { PDFImportView() } }
        .sheet(isPresented: $creating) { NavigationStack { ExerciseEditorView(item: nil) } }
        .sheet(item: $editing) { item in NavigationStack { ExerciseEditorView(item: item) } }
    }

    /// Drum part of a .mid file → a new exercise in "Bài của tôi".
    private func importMIDI(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let r = try MIDIFileImporter.exercise(from: data, title: url.deletingPathExtension().lastPathComponent,
                                                  overrides: SettingsStore.midiMap())
            context.insert(StoredExercise(title: r.exercise.title, dsl: ExerciseDSL.serialize(r.exercise, grid: ExerciseDSL.grid(for: r.exercise)), source: "MIDI"))
            try? context.save()
            midiMessage = "Đã nhập \(r.exercise.title): \(r.exercise.bars) ô nhịp, \(r.bpm) BPM"
                + (r.unmappedNotes > 0 ? ", bỏ qua \(r.unmappedNotes) nốt không phải trống." : ".")
        } catch {
            midiMessage = "Không đọc được file MIDI này. Hãy chọn file .mid có phần trống (kênh 10)."
        }
    }

    private var readingLines: [Exercise] {
        (1...30).map { (n: Int) -> Exercise in
            StickingGenerator.random(seed: UInt64(n), bars: 4, subdivision: n % 3 == 0 ? 4 : 2, rests: true)
        }
    }

    private func withSource(_ e: Exercise, _ s: String) -> Exercise { var x = e; x.source = s; return x }

    /// A row that opens the exercise; grooves also offer kick/snare permutations on long press.
    private func practiceLink(_ ex: Exercise) -> some View {
        let isGroove = Set(ex.notes.map(\.voice)).isSuperset(of: [.kick, .snare])
        return CardLink(ex.title, subtitle: "\(ex.timeSignature.beats)/\(ex.timeSignature.unit), \(ex.suggestedTempo.lowerBound)–\(ex.suggestedTempo.upperBound) BPM") {
            PracticeView(exercises: [ex], voiceBank: voiceBank)
        }
        .contextMenu {
            if isGroove {
                NavigationLink("Hoán vị kick") { ExerciseListPage(title: "Hoán vị kick", exercises: StickingGenerator.kickPermutations(ex), voiceBank: voiceBank) }
                NavigationLink("Hoán vị snare (nốt ma)") { ExerciseListPage(title: "Hoán vị snare", exercises: StickingGenerator.snarePermutations(ex), voiceBank: voiceBank) }
            }
        }
    }
}

/// A page listing generated or reference exercises (rudiments, stickings, permutations).
struct ExerciseListPage: View {
    let title: String
    let exercises: [Exercise]
    let voiceBank: CountVoiceBank

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: title, subtitle: "\(exercises.count) bài")
                CardSection {
                    ForEach(exercises) { ex in
                        CardLink(ex.title, subtitle: "\(ex.timeSignature.beats)/\(ex.timeSignature.unit), \(ex.suggestedTempo.lowerBound)–\(ex.suggestedTempo.upperBound) BPM") {
                            PracticeView(exercises: [ex], voiceBank: voiceBank)
                        }
                    }
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }
}
