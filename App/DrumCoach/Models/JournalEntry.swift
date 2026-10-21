import Foundation
import SwiftData

/// Free-text practice note (feelings, soreness, what was hard).
@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var text: String
    init(date: Date = Date(), text: String) {
        id = UUID()
        self.date = date
        self.text = text
    }
}
