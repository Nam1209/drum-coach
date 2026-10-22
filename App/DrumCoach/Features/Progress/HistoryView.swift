import DrumAnalysis
import DrumCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Practice log by day, plus backup export/import.
struct HistoryView: View {
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @Query(sort: \JournalEntry.date, order: .reverse) private var notes: [JournalEntry]
    @Environment(\.modelContext) private var context
    @State private var exportDoc: BackupDocument?
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            CardSection(L("Sao lưu", "Backup"), footer: message ?? L("Lịch sử còn nguyên khi cài lại app. Xuất file để giữ thêm một bản trong Tệp.", "Your history is kept when you reinstall the app. Export a file to keep another copy in Files.")) {
                CardButton(L("Xuất toàn bộ lịch sử ra file", "Export all history to a file"), systemImage: "square.and.arrow.up") {
                    if let f = try? HistoryStore.backup(context) { exportDoc = BackupDocument(file: f) }
                }
                CardButton(L("Nhập lại từ file sao lưu", "Restore from a backup file"), systemImage: "square.and.arrow.down") { importing = true }
            }
            if days.isEmpty { Text(L("Chưa có buổi tập nào.", "No sessions yet.")).foregroundStyle(.secondary) }
            ForEach(days, id: \.self) { day in
                CardSection(day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.current))) {
                    ForEach(notes.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }) { n in
                        Label(n.text, systemImage: "note.text").foregroundStyle(.secondary)
                    }
                    ForEach(sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.title)
                                Text(L("\(Int(s.bpm)) BPM, \(Int((s.seconds / 60).rounded(.up))) phút\(s.isLevelTest ? ", bài kiểm tra" : "")", "\(Int(s.bpm)) BPM, \(Int((s.seconds / 60).rounded(.up))) min\(s.isLevelTest ? ", level test" : "")"))
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(s.score.rounded()))%").font(Theme.number(17))
                                .foregroundStyle(s.score > 90 ? Theme.onTime : s.score >= 60 ? Theme.offTime : Theme.missed)
                        }
                    }
                }
            }
        }
        .fileExporter(isPresented: Binding(get: { exportDoc != nil }, set: { if !$0 { exportDoc = nil } }), document: exportDoc,
                      contentType: .json, defaultFilename: BackupFile.fileName(for: Date())) { result in
            message = (try? result.get()) != nil ? L("Đã xuất file backup.", "Backup file exported.") : nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard let url = try? result.get() else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let n = try HistoryStore.restore(BackupFile.decode(Data(contentsOf: url)), into: context)
                message = L("Đã nhập \(n) buổi tập.", "Imported \(n) sessions.")
            } catch {
                message = L("File không hợp lệ: \(error.localizedDescription)", "Invalid file: \(error.localizedDescription)")
            }
        }
    }

    private var days: [Date] {
        Array(Set(sessions.map { Calendar.current.startOfDay(for: $0.date) } + notes.map { Calendar.current.startOfDay(for: $0.date) }))
            .sorted(by: >)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let file: BackupFile
    init(file: BackupFile) { self.file = file }
    init(configuration: ReadConfiguration) throws {
        file = try BackupFile.decode(configuration.file.regularFileContents ?? Data())
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: try file.encoded()) }
}
