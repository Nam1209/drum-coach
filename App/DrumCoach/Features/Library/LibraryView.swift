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
                PageHeader(title: L("Thư viện", "Library")) {
                    HStack(spacing: 8) {
                        Button { importingMIDI = true } label: { Label(L("Nhập MIDI", "Import MIDI"), systemImage: "pianokeys") }.buttonStyle(.bordered)
                        Button { importing = true } label: { Label(L("Nhập PDF", "Import PDF"), systemImage: "doc.viewfinder") }.buttonStyle(.bordered)
                        Button { creating = true } label: { Label(L("Soạn bài", "New exercise"), systemImage: "plus") }.buttonStyle(.borderedProminent)
                    }
                }
                CardSection(L("Bài của tôi", "My exercises"), footer: midiMessage ?? (mine.isEmpty ? nil : L("Nhấn giữ một bài để sửa hoặc xóa.", "Press and hold an exercise to edit or delete it."))) {
                    if mine.isEmpty { Text(L("Chưa có bài nào. Soạn bài mới, nhập từ sách PDF hoặc từ file MIDI.", "No exercises yet. Write a new one, or import from a PDF book or a MIDI file.")).foregroundStyle(.secondary) }
                    ForEach(mine) { item in
                        if let ex = item.exercise {
                            practiceLink(ex)
                                .contextMenu {
                                    Button(L("Sửa", "Edit"), systemImage: "pencil") { editing = item }
                                    Button(L("Xóa", "Delete"), systemImage: "trash", role: .destructive) { context.delete(item) }
                                }
                        } else {
                            Text(L("\(item.title) (lỗi cú pháp)", "\(item.title) (syntax error)")).foregroundStyle(Theme.missed)
                                .contextMenu { Button(L("Xóa", "Delete"), systemImage: "trash", role: .destructive) { context.delete(item) } }
                        }
                    }
                    CardLink(L("Chơi theo nhạc", "Play along"), subtitle: L("Mở một bài hát hoặc backing track rồi chơi theo", "Open a song or backing track and play along")) { PlayAlongView() }
                }
                CardSection(L("Khởi động", "Warm-up"), footer: L("Nhấn giữ một groove để tạo các bài hoán vị kick hoặc snare.", "Press and hold a groove to make kick or snare permutation exercises.")) {
                    ForEach(StarterExercises.all) { practiceLink($0) }
                }
                HStack(alignment: .top, spacing: 22) {
                    CardSection("Rudiment") {
                        CardLink(L("40 rudiment chuẩn PAS", "40 PAS rudiments"), value: "\(PASRudiments.all.count)") { ExerciseListPage(title: L("40 rudiment chuẩn PAS", "40 PAS rudiments"), exercises: PASRudiments.all, voiceBank: voiceBank) }
                    }
                    CardSection(L("Kiểu Stick Control (tự sinh)", "Stick Control style (generated)"), footer: L("Mỗi bài lặp 20 lần không dừng rồi mới sang bài kế tiếp, theo lời dặn của G. L. Stone.", "Repeat each exercise 20 times without stopping before moving on, as G. L. Stone advises.")) {
                        LabeledContent(L("Số nốt", "Notes")) {
                            Picker(L("Số nốt", "Notes"), selection: $stickLength) { Text("4").tag(4); Text("8").tag(8) }.pickerStyle(.segmented).frame(width: 140)
                        }
                        Toggle(L("Chỉ tổ hợp cân bằng (số R bằng số L)", "Balanced patterns only (equal R and L)"), isOn: $balancedOnly)
                        CardLink(L("Danh sách tổ hợp", "Pattern list")) {
                            ExerciseListPage(title: L("Sticking \(stickLength) nốt", "\(stickLength)-note sticking"),
                                             exercises: StickingGenerator.singleBeat(length: stickLength, subdivision: 2, balancedOnly: balancedOnly), voiceBank: voiceBank)
                        }
                        CardLink(L("Đọc nhạc ngẫu nhiên", "Random reading"), value: L("30 bài", "30 exercises")) { ExerciseListPage(title: L("Đọc nhạc", "Reading"), exercises: readingLines, voiceBank: voiceBank) }
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
            midiMessage = L("Đã nhập \(r.exercise.title): \(r.exercise.bars) ô nhịp, \(r.bpm) BPM", "Imported \(r.exercise.title): \(r.exercise.bars) bars, \(r.bpm) BPM")
                + (r.unmappedNotes > 0 ? L(", bỏ qua \(r.unmappedNotes) nốt không phải trống.", ", skipped \(r.unmappedNotes) non-drum notes.") : ".")
        } catch {
            midiMessage = L("Không đọc được file MIDI này. Hãy chọn file .mid có phần trống (kênh 10).", "Couldn't read this MIDI file. Choose a .mid file with a drum part (channel 10).")
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
                NavigationLink(L("Hoán vị kick", "Kick permutations")) { ExerciseListPage(title: L("Hoán vị kick", "Kick permutations"), exercises: StickingGenerator.kickPermutations(ex), voiceBank: voiceBank) }
                NavigationLink(L("Hoán vị snare (nốt ma)", "Snare permutations (ghost notes)")) { ExerciseListPage(title: L("Hoán vị snare", "Snare permutations"), exercises: StickingGenerator.snarePermutations(ex), voiceBank: voiceBank) }
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
                PageHeader(title: title, subtitle: L("\(exercises.count) bài", exercises.count == 1 ? "1 exercise" : "\(exercises.count) exercises"))
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
