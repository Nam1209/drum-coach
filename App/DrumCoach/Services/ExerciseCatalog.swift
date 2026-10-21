import DrumCore
import DrumLibrary
import Foundation
import SwiftData

/// Every exercise the teacher may reference, by a stable id.
@MainActor
enum ExerciseCatalog {
    static func all(_ ctx: ModelContext?) -> [String: Exercise] {
        var out: [String: Exercise] = [:]
        for (i, e) in StarterExercises.all.enumerated() { out["start-\(i + 1)"] = e }
        for unit in Grade8Curriculum.units {
            for (i, dsl) in unit.exercises.enumerated() { if var e = try? ExerciseDSL.parse(dsl) { e.source = unit.skill; out["cur-\(unit.id)-\(i + 1)"] = e } }
        }
        for level in LevelCatalog.levels { for t in level.tests { if let e = try? ExerciseDSL.parse(t.dsl) { out[t.id] = e } } }
        if let ctx, let mine = try? ctx.fetch(FetchDescriptor<StoredExercise>()) {
            for s in mine { if let e = s.exercise { out[s.id.uuidString] = e } }
        }
        return out
    }

    static func titles(_ ctx: ModelContext?) -> [String: String] { all(ctx).mapValues(\.title) }
}
