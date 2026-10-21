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
