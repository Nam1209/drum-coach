import DrumCore
import Foundation
import SwiftData

/// A user-written (or imported) exercise, stored as DSL text.
@Model
final class StoredExercise {
    var id: UUID
    var title: String
    var dsl: String
    var source: String
    var tags: [String]
    var favorite: Bool
    var createdAt: Date

    init(title: String, dsl: String, source: String = "User", tags: [String] = [], favorite: Bool = false) {
        id = UUID()
        self.title = title
        self.dsl = dsl
        self.source = source
        self.tags = tags
        self.favorite = favorite
        createdAt = Date()
    }

    var exercise: Exercise? {
        guard var e = try? ExerciseDSL.parse(dsl) else { return nil }
        e.id = id
        e.source = source
        return e
    }
}
