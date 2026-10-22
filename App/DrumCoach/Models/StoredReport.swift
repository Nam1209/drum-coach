import DrumAI
import Foundation
import SwiftData

/// A teacher plan synced back from Notion (or produced via the API).
@Model
final class StoredReport {
    var id: UUID
    var title: String
    var created: Date
    var json: Data
    var appliedAt: Date?

    init(title: String, created: Date, report: TeacherReport) {
        id = UUID()
        self.title = title
        self.created = created
        json = (try? JSONEncoder().encode(report)) ?? Data()
    }

    var report: TeacherReport? { try? JSONDecoder().decode(TeacherReport.self, from: json) }
}

extension StoredReport {
    /// The plan in use: the one applied most recently (not the one created last; a revised plan can be applied later).
    static func active(in reports: [StoredReport]) -> StoredReport? {
        reports.filter { $0.appliedAt != nil }.max { $0.appliedAt! < $1.appliedAt! }
    }
}
