import DrumAI
import DrumCore
import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Import exercises from a page of a book the user owns: Claude reads the page and writes DSL; the user reviews and saves.
struct PDFImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("claude.model") private var model = ClaudeClient.defaultModel
    @State private var document: PDFDocument?
    @State private var pageIndex = 0
    @State private var pickingFile = false
    @State private var pasted = ""
    @State private var working = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Button(document == nil ? "Chọn file PDF…" : "Đổi file PDF…") { pickingFile = true }
                if let document {
                    Stepper("Trang \(pageIndex + 1) / \(document.pageCount)", value: $pageIndex, in: 0...max(0, document.pageCount - 1))
                    if let img = pageImage(width: 700) { Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 420) }
                }
            } footer: {
                Text("Chỉ dùng với sách bạn sở hữu. Dữ liệu chỉ lưu trên máy này.")
            }
            if document != nil {
                Section("Cách 1 · Claude API (nếu đã nhập key)") {
                    Button(working ? "Claude đang đọc trang…" : "Đọc trang này bằng Claude") { Task { await transcribe() } }
                        .disabled(working || (Keychain.get(Keychain.claudeKey) ?? "").isEmpty)
                }
                Section {
                    if let png = pageImage(width: 1600)?.pngData() {
                        ShareLink(item: PageImage(data: png), preview: SharePreview("Trang \(pageIndex + 1)")) {
                            Label("Gửi ảnh trang sang app Claude", systemImage: "square.and.arrow.up")
                        }
                        .simultaneousGesture(TapGesture().onEnded { UIPasteboard.general.string = PageTranscriber.instructions })
                    }
                    TextEditor(text: $pasted).font(.system(.body, design: .monospaced)).frame(minHeight: 160)
                } header: {
                    Text("Cách 2 · Gói Claude Pro")
                } footer: {
                    Text("Hướng dẫn đã được copy sẵn: dán vào Claude cùng ảnh trang, rồi dán kết quả (các bài cách nhau bằng dòng trống) vào ô trên.")
                }
            }
            let found = Self.split(pasted).compactMap { try? ExerciseDSL.parse($0) }
            if !found.isEmpty {
                Section("Xem trước (\(found.count) bài)") {
                    ForEach(found) { ex in
                        VStack(alignment: .leading) {
                            Text(ex.title).font(.headline)
                            NotationView(exercise: ex, display: .page, beat: nil).frame(height: 180)
                        }
                    }
                    Button("Lưu \(found.count) bài vào Thư viện") { save() }.buttonStyle(.borderedProminent)
                }
            }
            if let message { Text(message) }
        }
        .navigationTitle("Nhập từ PDF")
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.pdf]) { result in
            guard let url = try? result.get() else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            document = PDFDocument(url: url)
            pageIndex = 0
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } } }
    }

    private func pageImage(width: CGFloat) -> UIImage? {
        guard let page = document?.page(at: pageIndex) else { return nil }
        let box = page.bounds(for: .mediaBox)
        return page.thumbnail(of: CGSize(width: width, height: width * box.height / max(box.width, 1)), for: .mediaBox)
    }

    private func transcribe() async {
        guard let png = pageImage(width: 1600)?.pngData(), let key = Keychain.get(Keychain.claudeKey) else { return }
        working = true; defer { working = false }
        do {
            let dsl = try await PageTranscriber.transcribe(pagePNG: png, client: ClaudeClient(apiKey: key, model: model))
            pasted = dsl.joined(separator: "\n\n")
            message = dsl.isEmpty ? "Không đọc được bài nào trên trang này." : nil
        } catch {
            message = "Lỗi Claude: \(error)"
        }
    }

    private func save() {
        for block in Self.split(pasted) {
            guard let ex = try? ExerciseDSL.parse(block) else { continue }
            context.insert(StoredExercise(title: ex.title, dsl: block, source: "Sách của tôi"))
        }
        try? context.save()
        message = "Đã lưu vào Thư viện › Bài của tôi."
        pasted = ""
    }

    /// Exercises are separated by blank lines; a block starts at its "title:" line.
    static func split(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

struct PageImage: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}
