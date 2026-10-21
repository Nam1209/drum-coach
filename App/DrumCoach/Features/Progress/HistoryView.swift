import DrumAnalysis
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
        List {
            Section("Backup") {
                Button("Xuất toàn bộ lịch sử ra file…") {
                    if let f = try? HistoryStore.backup(context) { exportDoc = BackupDocument(file: f) }
                }
                Button("Nhập lại từ file backup…") { importing = true }
                if let message { Text(message).foregroundStyle(.secondary) }
            }
            ForEach(days, id: \.self) { day in
                Section(day.formatted(date: .complete, time: .omitted)) {
                    ForEach(notes.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }) { n in
                        Label(n.text, systemImage: "note.text").foregroundStyle(.secondary)
                    }
                    ForEach(sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }) { s in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(s.title)
                                Text("\(Int(s.bpm)) BPM · \(Int((s.seconds / 60).rounded(.up))) phút\(s.isLevelTest ? " · TEST" : "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(s.score.rounded()))%").bold().monospacedDigit()
                                .foregroundStyle(s.score > 90 ? .green : s.score >= 60 ? .orange : .red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Lịch sử")
        .fileExporter(isPresented: Binding(get: { exportDoc != nil }, set: { if !$0 { exportDoc = nil } }), document: exportDoc,
                      contentType: .json, defaultFilename: BackupFile.fileName(for: Date())) { result in
            message = (try? result.get()) != nil ? "Đã xuất file backup." : nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard let url = try? result.get() else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let n = try HistoryStore.restore(BackupFile.decode(Data(contentsOf: url)), into: context)
                message = "Đã nhập \(n) buổi tập."
            } catch {
                message = "File không hợp lệ: \(error.localizedDescription)"
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
