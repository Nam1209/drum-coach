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
                Text("x/o = đánh · X/O = accent · g = ghost · f = flam · d = drag · z = buzz · - = nghỉ · | = vạch nhịp. Voice: HH OH HP SN SS BD T1 T2 FT RD CR. ST: R/L/F.")
            }
            Section("Xem trước") {
                switch parsed {
                case .success(let ex):
                    NotationView(exercise: ex, display: .page, beat: nil)
                case .failure(let err):
                    Text(message(err)).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(item == nil ? "Soạn bài" : "Sửa bài")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") { save() }.disabled((try? parsed.get()) == nil)
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
        case .missingHeader(let h): "Thiếu dòng \"\(h):\""
        case .unequalLineLengths: "Các dòng nhạc phải dài bằng nhau"
        case .unknownVoice(let v): "Không biết voice \"\(v)\""
        case .badSymbol(let c, let line): "Ký tự \"\(c)\" không hợp lệ ở dòng \(line)"
        case .lengthNotMultipleOfBar: "Độ dài chưa đủ trọn ô nhịp (grid × số phách)"
        }
    }
}
