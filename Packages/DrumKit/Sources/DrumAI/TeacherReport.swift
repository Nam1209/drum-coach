import Foundation

public struct AdviceItem: Codable, Sendable, Equatable {
    public let date: Date
    public let text: String
    /// Filled in by a later report: did the student follow it?
    public var followed: Bool?
    public init(date: Date, text: String, followed: Bool? = nil) { self.date = date; self.text = text; self.followed = followed }
}

/// What the teacher remembers about the student between reports.
public struct StudentProfile: Codable, Sendable, Equatable {
    public var goal = "Rockschool Grade 8"
    public var instruments = ["pad 12\"", "Roland TD-7", "5A sticks"]
    public var minutesPerDay = 30
    public var notes: [String] = []
    public var pastAdvice: [AdviceItem] = []
    public init() {}
}

public struct Resource: Codable, Sendable, Equatable, Hashable {
    /// "youtube" | "article" | "book"
    public let kind: String
    public let title: String
    public var url: URL?
    public let why: String
    public let searchQuery: String

    public init(kind: String, title: String, url: URL?, why: String, searchQuery: String) {
        self.kind = kind; self.title = title; self.url = url; self.why = why; self.searchQuery = searchQuery
    }
}

public struct PlannedItem: Codable, Sendable, Equatable, Hashable {
    /// An exercise from the app library, or nil when `newExerciseDSL` is given.
    public let exerciseId: String?
    public let newExerciseDSL: String?
    public let bpm: Int
    public let minutes: Int
    public let focus: String

    public init(exerciseId: String?, newExerciseDSL: String?, bpm: Int, minutes: Int, focus: String) {
        self.exerciseId = exerciseId; self.newExerciseDSL = newExerciseDSL; self.bpm = bpm; self.minutes = minutes; self.focus = focus
    }
}

public struct DayPlan: Codable, Sendable, Equatable, Hashable {
    /// 1…7
    public let day: Int
    public let warmup: [PlannedItem]
    public let main: [PlannedItem]
    public let fun: [PlannedItem]

    public var allItems: [PlannedItem] { warmup + main + fun }

    public init(day: Int, warmup: [PlannedItem], main: [PlannedItem], fun: [PlannedItem]) {
        self.day = day; self.warmup = warmup; self.main = main; self.fun = fun
    }
}

public struct TeacherReport: Codable, Sendable, Equatable {
    public let summary: String
    public let progress: [String]
    /// At most 3, most important first.
    public let fixFirst: [String]
    public let likelyCauses: [String]
    public let weekPlan: [DayPlan]
    public var resources: [Resource]
    public let nextCheckpoint: String

    public init(summary: String, progress: [String], fixFirst: [String], likelyCauses: [String], weekPlan: [DayPlan],
                resources: [Resource], nextCheckpoint: String) {
        self.summary = summary; self.progress = progress; self.fixFirst = fixFirst; self.likelyCauses = likelyCauses
        self.weekPlan = weekPlan; self.resources = resources; self.nextCheckpoint = nextCheckpoint
    }
}

import DrumCore

extension TeacherReport {
    /// A plan coming back from Notion is untrusted text: keep only days 1–7, items whose exercise exists or whose DSL parses,
    /// tempos 30–300 and 1–120 minutes; at most 3 things to fix; short strings.
    public func sanitized(knownExerciseIds: Set<String>) -> TeacherReport {
        func ok(_ i: PlannedItem) -> Bool {
            guard (30...300).contains(i.bpm), (1...120).contains(i.minutes), i.focus.count <= 500 else { return false }
            if let id = i.exerciseId, knownExerciseIds.contains(id) { return true }
            if let dsl = i.newExerciseDSL, dsl.count <= 5_000, (try? ExerciseDSL.parse(dsl)) != nil { return true }
            return false
        }
        func short(_ xs: [String], _ n: Int) -> [String] { Array(xs.prefix(n).map { String($0.prefix(600)) }) }
        let days = weekPlan.filter { (1...7).contains($0.day) }
            .map { DayPlan(day: $0.day, warmup: $0.warmup.filter(ok), main: $0.main.filter(ok), fun: $0.fun.filter(ok)) }
        let links = resources.prefix(10).map { r in
            Resource(kind: ["youtube", "article", "book"].contains(r.kind) ? r.kind : "article", title: String(r.title.prefix(200)),
                     url: r.url.flatMap { $0.scheme?.lowercased() == "https" && $0.host != nil ? $0 : nil },
                     why: String(r.why.prefix(500)), searchQuery: String(r.searchQuery.prefix(200)))
        }
        return TeacherReport(summary: String(summary.prefix(2_000)), progress: short(progress, 10), fixFirst: short(fixFirst, 3),
                             likelyCauses: short(likelyCauses, 5), weekPlan: days, resources: links,
                             nextCheckpoint: String(nextCheckpoint.prefix(600)))
    }
}
