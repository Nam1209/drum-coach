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
                Button(document == nil ? L("Chọn file PDF…", "Choose PDF file…") : L("Đổi file PDF…", "Change PDF file…")) { pickingFile = true }
                if let document {
                    Stepper(L("Trang \(pageIndex + 1) / \(document.pageCount)", "Page \(pageIndex + 1) / \(document.pageCount)"), value: $pageIndex, in: 0...max(0, document.pageCount - 1))
                    if let img = pageImage(width: 700) { Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 420) }
                }
            } footer: {
                Text(L("Chỉ dùng với sách bạn sở hữu. Dữ liệu chỉ lưu trên máy này.", "Only use this with books you own. Data stays on this device."))
            }
            if document != nil {
                Section(L("Cách 1 · Claude API (nếu đã nhập key)", "Option 1 · Claude API (if you added a key)")) {
                    Button(working ? L("Claude đang đọc trang…", "Claude is reading the page…") : L("Đọc trang này bằng Claude", "Read this page with Claude")) { Task { await transcribe() } }
                        .disabled(working || (Keychain.get(Keychain.claudeKey) ?? "").isEmpty)
                }
                Section {
                    if let png = pageImage(width: 1600)?.pngData() {
                        ShareLink(item: PageImage(data: png), preview: SharePreview(L("Trang \(pageIndex + 1)", "Page \(pageIndex + 1)"))) {
                            Label(L("Gửi ảnh trang sang app Claude", "Send page image to the Claude app"), systemImage: "square.and.arrow.up")
                        }
                        .simultaneousGesture(TapGesture().onEnded { UIPasteboard.general.string = PageTranscriber.instructions })
                    }
                    TextEditor(text: $pasted).font(.system(.body, design: .monospaced)).frame(minHeight: 160)
                } header: {
                    Text(L("Cách 2 · Gói Claude Pro", "Option 2 · Claude Pro plan"))
                } footer: {
                    Text(L("Hướng dẫn đã được copy sẵn: dán vào Claude cùng ảnh trang, rồi dán kết quả (các bài cách nhau bằng dòng trống) vào ô trên.", "Instructions are already copied: paste them into Claude with the page image, then paste the result (exercises separated by blank lines) into the box above."))
                }
            }
            let found = Self.split(pasted).compactMap { try? ExerciseDSL.parse($0) }
            if !found.isEmpty {
                Section(L("Xem trước (\(found.count) bài)", "Preview (\(found.count) exercises)")) {
                    ForEach(found) { ex in
                        VStack(alignment: .leading) {
                            Text(ex.title).font(.headline)
                            NotationView(exercise: ex, display: .page, beat: nil).frame(height: 180)
                        }
                    }
                    Button(L("Lưu \(found.count) bài vào Thư viện", "Save \(found.count) exercises to Library")) { save() }.buttonStyle(.borderedProminent)
                }
            }
            if let message { Text(message) }
        }
        .navigationTitle(L("Nhập từ PDF", "Import from PDF"))
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.pdf]) { result in
            guard let url = try? result.get() else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            document = PDFDocument(url: url)
            pageIndex = 0
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Đóng", "Close")) { dismiss() } } }
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
            message = dsl.isEmpty ? L("Không đọc được bài nào trên trang này.", "Couldn't read any exercises on this page.") : nil
        } catch {
            message = error.userMessage
        }
    }

    private func save() {
        for block in Self.split(pasted) {
            guard let ex = try? ExerciseDSL.parse(block) else { continue }
            context.insert(StoredExercise(title: ex.title, dsl: block, source: L("Sách của tôi", "My books")))
        }
        try? context.save()
        message = L("Đã lưu vào Thư viện › Bài của tôi.", "Saved to Library › My exercises.")
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
