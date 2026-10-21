import DrumCore
import SwiftData
import SwiftUI

/// Edit exercise DSL with a live notation preview and line-numbered parse errors.
struct ExerciseEditorView: View {
    let item: StoredExercise?
    @State private var text: String
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(item: StoredExercise?) {
        self.item = item
        _text = State(initialValue: item?.dsl ?? """
        title: Bài mới
        title_en: New exercise
        time: 4/4
        tempo: 60-100
        grid: 4
        HH: x-x-x-x-x-x-x-x-
        SN: ----x-------x---
        BD: x-------x-x-----
        """)
    }

    private var parsed: Result<Exercise, DSLError> {
        do { return .success(try ExerciseDSL.parse(text)) } catch { return .failure(error) }
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } footer: {
                Text(L("x/o = đánh · X/O = accent · g = ghost · f = flam · d = drag · z = buzz · - = nghỉ · | = vạch nhịp. Voice: HH OH HP SN SS BD T1 T2 FT RD CR. ST: R/L/F.", "x/o = hit · X/O = accent · g = ghost · f = flam · d = drag · z = buzz · - = rest · | = bar line. Voice: HH OH HP SN SS BD T1 T2 FT RD CR. ST: R/L/F."))
            }
            Section(L("Xem trước", "Preview")) {
                switch parsed {
                case .success(let ex):
                    NotationView(exercise: ex, display: .page, beat: nil)
                case .failure(let err):
                    Text(message(err)).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(item == nil ? L("Soạn bài", "New exercise") : L("Sửa bài", "Edit exercise"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(L("Hủy", "Cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("Lưu", "Save")) { save() }.disabled((try? parsed.get()) == nil)
            }
        }
    }

    private func save() {
        guard case .success(let ex) = parsed else { return }
        if let item {
            item.dsl = text
            item.title = ex.title
        } else {
            context.insert(StoredExercise(title: ex.title, dsl: text))
        }
        try? context.save()
        dismiss()
    }

    private func message(_ e: DSLError) -> String {
        switch e {
        case .missingHeader(let h): L("Thiếu dòng \"\(h):\"", "Missing line \"\(h):\"")
        case .unequalLineLengths: L("Các dòng nhạc phải dài bằng nhau", "All music lines must be the same length")
        case .unknownVoice(let v): L("Không biết voice \"\(v)\"", "Unknown voice \"\(v)\"")
        case .badSymbol(let c, let line): L("Ký tự \"\(c)\" không hợp lệ ở dòng \(line)", "Invalid character \"\(c)\" on line \(line)")
        case .lengthNotMultipleOfBar: L("Độ dài chưa đủ trọn ô nhịp (grid × số phách)", "Length isn't a whole number of bars (grid × beats)")
        }
    }
}
