import DrumAI
import DrumAnalysis
import DrumCore
import Foundation
import SwiftData
import UIKit

/// Settings and actions for the Claude Pro ↔ Notion teacher loop.
@MainActor
enum TeacherConnection {
    private static let d = UserDefaults.standard

    static var rootPageId: String? { get { d.string(forKey: "notion.root") } set { d.set(newValue, forKey: "notion.root") } }
    static var inboxPageId: String? { get { d.string(forKey: "notion.inbox") } set { d.set(newValue, forKey: "notion.inbox") } }
    static var plansPageId: String? { get { d.string(forKey: "notion.plans") } set { d.set(newValue, forKey: "notion.plans") } }
    static var exercisesPageId: String? { get { d.string(forKey: "notion.exercises") } set { d.set(newValue, forKey: "notion.exercises") } }
    static var lastPlanSync: Date? { get { d.object(forKey: "notion.lastPlanSync") as? Date } set { d.set(newValue, forKey: "notion.lastPlanSync") } }
    static var lastExerciseSync: Date? { get { d.object(forKey: "notion.lastExSync") as? Date } set { d.set(newValue, forKey: "notion.lastExSync") } }

    static var isConfigured: Bool { Keychain.get(Keychain.notionToken) != nil && inboxPageId != nil && plansPageId != nil }

    static var profile: StudentProfile {
        get { d.data(forKey: "teacher.profile").flatMap { try? JSONDecoder().decode(StudentProfile.self, from: $0) } ?? StudentProfile() }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: "teacher.profile") }
    }

    static var bridge: NotionBridge? {
        guard let token = Keychain.get(Keychain.notionToken), let inbox = inboxPageId, let plans = plansPageId else { return nil }
        return NotionBridge(client: NotionClient(token: token), inboxPageId: inbox, plansPageId: plans, exercisesPageId: exercisesPageId)
    }

    /// Creates "Hộp thư", "Kế hoạch" and "Bài tập mới" under the user's DrumCoach page.
    static func setUp(token: String, rootLink: String) async throws {
        guard let root = NotionClient.pageId(fromLink: rootLink) else { throw NotionError.badResponse }
        Keychain.set(token, for: Keychain.notionToken)
        let client = NotionClient(token: token)
        inboxPageId = try await client.createChildPage(parent: root, title: "Hộp thư")
        plansPageId = try await client.createChildPage(parent: root, title: "Kế hoạch")
        exercisesPageId = try await client.createChildPage(parent: root, title: "Bài tập mới")
        rootPageId = root
    }

    /// Upload the weekly digest (plus a full backup), copy the message, and open the Claude app.
    static func sendWeekly(_ ctx: ModelContext) async throws -> String {
        guard let bridge else { throw NotionError.badResponse }
        let out = try await bridge.send(kind: .weekly, payload: HistoryStore.digest(ctx), profile: profile, date: Date())
        if let backup = try? HistoryStore.backup(ctx) {
            _ = try? await bridge.send(kind: .backup, payload: backup, profile: profile, date: Date())
        }
        handOff(out.prompt)
        return out.pageTitle
    }

    static func sendPeriod(_ review: PeriodReview) async throws -> String {
        guard let bridge else { throw NotionError.badResponse }
        let out = try await bridge.send(kind: .period, payload: review, profile: profile, date: Date())
        handOff(out.prompt)
        return out.pageTitle
    }

    static func handOff(_ prompt: String) {
        UIPasteboard.general.string = prompt
        if let url = URL(string: "https://claude.ai/new") { UIApplication.shared.open(url) }
    }

    /// Pull new plans and exercises. New plans are stored but not applied (the user confirms first).
    static func sync(_ ctx: ModelContext) async throws -> (plans: [StoredReport], exercises: Int, problems: [String]) {
        guard let bridge else { return ([], 0, []) }
        let known = Set(ExerciseCatalog.all(ctx).keys)
        var stored: [StoredReport] = [], problems: [String] = []
        for p in try await bridge.fetchNewPlans(after: lastPlanSync) {
            switch p.report {
            case .success(let r):
                var clean = r.sanitized(knownExerciseIds: known)
                clean.resources = await ResourceValidator().validate(clean.resources)
                let s = StoredReport(title: p.title, created: p.created, report: clean)
                ctx.insert(s)
                stored.append(s)
            case .failure(let e):
                problems.append("\(p.title): \(e.userMessage)")
            }
            lastPlanSync = max(lastPlanSync ?? .distantPast, p.created)
        }
        let newExercises = try await bridge.fetchNewExercises(after: lastExerciseSync)
        for dsl in newExercises {
            if let e = try? DrumCore.ExerciseDSL.parse(dsl) { ctx.insert(StoredExercise(title: e.title, dsl: dsl, source: "Sách của tôi")) }
        }
        if !newExercises.isEmpty { lastExerciseSync = Date() }
        try ctx.save()
        return (stored, newExercises.count, problems)
    }

    /// API path: Claude writes the weekly report directly (needs an API key).
    static func weeklyReportViaAPI(_ ctx: ModelContext, apiKey: String, model: String) async throws -> StoredReport {
        let catalog = ExerciseCatalog.titles(ctx)
        var r = try await Teacher.weeklyReport(digest: HistoryStore.digest(ctx), profile: profile, library: catalog,
                                               client: ClaudeClient(apiKey: apiKey, model: model))
            .sanitized(knownExerciseIds: Set(catalog.keys))
        r.resources = await ResourceValidator().validate(r.resources)
        let stored = StoredReport(title: "Kế hoạch \(NotionBridge.dayString(Date()))", created: Date(), report: r)
        ctx.insert(stored)
        try ctx.save()
        return stored
    }

    static func estimatedAPICost(_ ctx: ModelContext) -> Double {
        let bytes = (try? JSONEncoder().encode(HistoryStore.digest(ctx)).count) ?? 10_000
        return Teacher.estimatedCostUSD(inputBytes: bytes)
    }

    /// Make a plan active: its new exercises join the library and its "fix first" items become remembered advice.
    static func apply(_ stored: StoredReport, _ ctx: ModelContext) {
        guard let r = stored.report else { return }
        for item in r.weekPlan.flatMap(\.allItems) {
            if let dsl = item.newExerciseDSL, let e = try? DrumCore.ExerciseDSL.parse(dsl) {
                ctx.insert(StoredExercise(title: e.title, dsl: dsl, source: "Thầy AI"))
            }
        }
        var p = profile
        p.pastAdvice += r.fixFirst.map { AdviceItem(date: stored.created, text: $0) }
        p.pastAdvice = Array(p.pastAdvice.suffix(30))
        profile = p
        stored.appliedAt = Date()
        try? ctx.save()
    }
}
