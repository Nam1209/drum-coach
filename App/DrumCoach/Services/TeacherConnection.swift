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
    /// Notion page ids already imported successfully (plans / exercise pages).
    static var importedPlanPages: Set<String> {
        get { Set(d.stringArray(forKey: "notion.importedPlans") ?? []) }
        set { d.set(Array(newValue), forKey: "notion.importedPlans") }
    }
    static var importedExercisePages: Set<String> {
        get { Set(d.stringArray(forKey: "notion.importedExercises") ?? []) }
        set { d.set(Array(newValue), forKey: "notion.importedExercises") }
    }
    /// One sync at a time (auto-sync on foreground + the button could otherwise race and import duplicates).
    private static var syncing = false

    static var lastNotionBackup: Date? { get { d.object(forKey: "notion.lastBackup") as? Date } set { d.set(newValue, forKey: "notion.lastBackup") } }

    static var isConfigured: Bool { Keychain.get(Keychain.notionToken) != nil && inboxPageId != nil && plansPageId != nil }

    static var profile: StudentProfile {
        get {
            var p = d.data(forKey: "teacher.profile").flatMap { try? JSONDecoder().decode(StudentProfile.self, from: $0) } ?? StudentProfile()
            // Profiles saved before the kit was corrected say TD-7; the kit is a TD-4K.
            p.instruments = p.instruments.map { $0 == "Roland TD-7" ? "Roland TD-4K" : $0 }
            return p
        }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: "teacher.profile") }
    }

    static var bridge: NotionBridge? {
        guard let token = Keychain.get(Keychain.notionToken), let inbox = inboxPageId, let plans = plansPageId else { return nil }
        return NotionBridge(client: NotionClient(token: token), inboxPageId: inbox, plansPageId: plans, exercisesPageId: exercisesPageId)
    }

    static var guideTitle: String { L("Hướng dẫn cho thầy", "Teacher guide") }

    /// One step: with just the token, find the page shared with the integration, set up "Hộp thư", "Kế hoạch",
    /// "Bài tập mới" and the teacher guide inside it.
    static func connect(token: String, catalog: [String: String]) async throws {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let client = NotionClient(token: token)
        let ws = try await NotionSetup.connect(client: client, titles: .init(inbox: L("Hộp thư", "Inbox"), plans: L("Kế hoạch", "Plans"),
                                                                            exercises: L("Bài tập mới", "New exercises")))
        Keychain.set(token, for: Keychain.notionToken)
        rootPageId = ws.root; inboxPageId = ws.inbox; plansPageId = ws.plans; exercisesPageId = ws.exercises
        try await publishGuide(catalog: catalog)
    }

    /// The teacher's instructions live in Notion, so no Claude Project has to be set up or kept up to date by hand.
    static func publishGuide(catalog: [String: String]) async throws {
        guard let token = Keychain.get(Keychain.notionToken), let root = rootPageId else { return }
        try await NotionSetup.publishGuide(client: NotionClient(token: token), root: root, title: guideTitle,
                                           text: TeacherProjectKit.projectInstructions(exerciseCatalog: catalog))
    }

    /// Upload the weekly digest (plus a full backup), copy the message, and open the Claude app.
    static func sendWeekly(_ ctx: ModelContext) async throws -> String {
        guard let bridge else { throw NotionError.badResponse }
        let out = try await bridge.send(kind: .weekly, payload: HistoryStore.digest(ctx), profile: profile, date: Date())
        try? await publishGuide(catalog: ExerciseCatalog.titles(ctx))   // keeps the exercise list in the guide current
        handOff(out.prompt)
        do {
            _ = try await bridge.send(kind: .backup, payload: try HistoryStore.backup(ctx), profile: profile, date: Date())
            lastNotionBackup = Date()
        } catch {
            // The report went through; tell the user the off-device backup did not.
            return out.pageTitle + L(" (chưa sao lưu lên Notion được: \(Friendly.message(error)))", " (could not back up to Notion: \(Friendly.message(error)))")
        }
        return out.pageTitle
    }

    static func sendPeriod(_ review: PeriodReview) async throws -> String {
        guard let bridge else { throw NotionError.badResponse }
        let out = try await bridge.send(kind: .period, payload: review, profile: profile, date: Date())
        handOff(out.prompt)
        return out.pageTitle
    }

    static func handOff(_ prompt: String) {
        let intro = L("Dùng connector Notion: đọc trang \"DrumCoach › \(guideTitle)\" và làm đúng theo đó. ",
                      "Use the Notion connector: read the page \"DrumCoach › \(guideTitle)\" and follow it exactly. ")
        UIPasteboard.general.string = intro + prompt
        if let url = URL(string: "https://claude.ai/new") { UIApplication.shared.open(url) }
    }

    /// Pull new plans and exercises. New plans are stored but not applied (the user confirms first).
    static func sync(_ ctx: ModelContext) async throws -> (plans: [StoredReport], exercises: Int, problems: [String]) {
        guard let bridge, !syncing else { return ([], 0, []) }
        syncing = true
        defer { syncing = false }
        let known = Set(ExerciseCatalog.all(ctx).keys)
        var stored: [StoredReport] = [], problems: [String] = []
        for p in try await bridge.fetchPlans(excluding: importedPlanPages) {
            switch p.report {
            case .success(let r):
                var clean = r.sanitized(knownExerciseIds: known)
                clean.resources = await ResourceValidator().validate(clean.resources)
                let s = StoredReport(title: p.title, created: p.created, report: clean)
                ctx.insert(s)
                stored.append(s)
                importedPlanPages.insert(p.pageId)
            case .failure(let e):
                problems.append("\(p.title): \(e.userMessage)")   // not marked imported: retried next sync
            }
        }
        var added = 0
        for page in try await bridge.fetchExercisePages(excluding: importedExercisePages) where !page.dsl.isEmpty {
            for dsl in page.dsl {
                if let e = try? DrumCore.ExerciseDSL.parse(dsl) { ctx.insert(StoredExercise(title: e.title, dsl: dsl, source: L("Sách của tôi", "My books"))); added += 1 }
            }
            importedExercisePages.insert(page.pageId)
        }
        try ctx.save()
        return (stored, added, problems)
    }

    /// API path: Claude writes the weekly report directly (needs an API key).
    static func weeklyReportViaAPI(_ ctx: ModelContext, apiKey: String, model: String) async throws -> StoredReport {
        let catalog = ExerciseCatalog.titles(ctx)
        var r = try await Teacher.weeklyReport(digest: HistoryStore.digest(ctx), profile: profile, library: catalog,
                                               client: ClaudeClient(apiKey: apiKey, model: model))
            .sanitized(knownExerciseIds: Set(catalog.keys))
        r.resources = await ResourceValidator().validate(r.resources)
        let stored = StoredReport(title: L("Kế hoạch \(NotionBridge.dayString(Date()))", "Plan \(NotionBridge.dayString(Date()))"), created: Date(), report: r)
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
                ctx.insert(StoredExercise(title: e.title, dsl: dsl, source: L("Thầy AI", "AI teacher")))
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
