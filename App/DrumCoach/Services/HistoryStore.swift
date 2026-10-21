import DrumAI
import DrumAnalysis
import DrumCore
import Foundation
import SwiftData

/// Converts stored sessions to the analysis/backup types and runs backups.
@MainActor
enum HistoryStore {
    static func records(_ ctx: ModelContext) -> [SessionRecord] {
        let all = (try? ctx.fetch(FetchDescriptor<PracticeSession>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return all.compactMap { s in
            s.stats.map { SessionRecord(date: s.date, exerciseId: s.exerciseId, title: s.title, skill: s.skill, bpm: s.bpm,
                                        minutes: s.seconds / 60, stats: $0, isLevelTest: s.isLevelTest) }
        }
    }

    /// Total practice points over the whole history, oldest first.
    static func totalPoints(_ ctx: ModelContext) -> Int {
        let all = (try? ctx.fetch(FetchDescriptor<PracticeSession>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return PracticePoints.total(all.map(\.points))
    }

    static func journal(_ ctx: ModelContext) -> [(Date, String)] {
        ((try? ctx.fetch(FetchDescriptor<JournalEntry>())) ?? []).map { ($0.date, $0.text) }
    }

    static func digest(_ ctx: ModelContext) -> HistoryDigest {
        HistorySummarizer.digest(records(ctx), journal: journal(ctx), currentLevel: SettingsStore.currentGrade, now: Date(), calendar: .current)
    }

    static func backup(_ ctx: ModelContext) throws -> BackupFile {
        let sessions = (try ctx.fetch(FetchDescriptor<PracticeSession>())).compactMap { s -> BackupSession? in
            guard let stats = s.stats else { return nil }
            return BackupSession(id: s.id, date: s.date, exerciseId: s.exerciseId, title: s.title, skill: s.skill, bpm: s.bpm,
                                 seconds: s.seconds, mode: s.mode, goodWindowMs: s.goodWindowMs, stats: stats,
                                 isLevelTest: s.isLevelTest, levelTestId: s.levelTestId, assessment: s.assessmentData)
        }
        let notes = (try ctx.fetch(FetchDescriptor<JournalEntry>())).map { BackupJournal(id: $0.id, date: $0.date, text: $0.text) }
        let exercises = (try ctx.fetch(FetchDescriptor<StoredExercise>())).map {
            BackupExercise(id: $0.id, title: $0.title, dsl: $0.dsl, source: $0.source, tags: $0.tags, favorite: $0.favorite, createdAt: $0.createdAt)
        }
        let reports = (try ctx.fetch(FetchDescriptor<StoredReport>())).map {
            BackupReport(id: $0.id, title: $0.title, created: $0.created, json: $0.json, appliedAt: $0.appliedAt)
        }
        let settings = BackupSettings(
            levelHistory: Dictionary(uniqueKeysWithValues: SettingsStore.levelHistory.map { (String($0.0), $0.1) }),
            latencyMs: Dictionary(uniqueKeysWithValues: InputMode.allCases.map { ($0.rawValue, SettingsStore.latency(for: $0) * 1000) }),
            midiMap: Dictionary(uniqueKeysWithValues: SettingsStore.midiMap().map { (String($0.key), $0.value.rawValue) }),
            currentGrade: SettingsStore.currentGrade,
            teacherProfile: try? JSONEncoder().encode(TeacherConnection.profile))
        return BackupFile(exportedAt: Date(), sessions: sessions, journal: notes, exercises: exercises, reports: reports, settings: settings)
    }

    /// Adds sessions and notes that are not already present. Returns how many sessions were added.
    @discardableResult
    static func restore(_ file: BackupFile, into ctx: ModelContext) throws -> Int {
        let existing = Set((try ctx.fetch(FetchDescriptor<PracticeSession>())).map(\.id))
        let new = file.newSessions(existing: existing)
        for b in new {
            let s = PracticeSession(date: b.date, exerciseId: b.exerciseId, title: b.title, skill: b.skill, bpm: b.bpm, seconds: b.seconds,
                                    mode: b.mode, goodWindowMs: b.goodWindowMs, stats: b.stats, isLevelTest: b.isLevelTest, levelTestId: b.levelTestId)
            s.id = b.id
            s.assessmentData = b.assessment
            ctx.insert(s)
        }
        let notes = Set((try ctx.fetch(FetchDescriptor<JournalEntry>())).map(\.id))
        for j in file.saneJournal where !notes.contains(j.id) {
            let e = JournalEntry(date: j.date, text: j.text)
            e.id = j.id
            ctx.insert(e)
        }
        let haveExercises = Set((try ctx.fetch(FetchDescriptor<StoredExercise>())).map(\.id))
        for b in file.saneExercises where !haveExercises.contains(b.id) {
            let e = StoredExercise(title: b.title, dsl: b.dsl, source: b.source, tags: Array(b.tags.prefix(20)), favorite: b.favorite)
            e.id = b.id
            e.createdAt = b.createdAt
            ctx.insert(e)
        }
        let haveReports = Set((try ctx.fetch(FetchDescriptor<StoredReport>())).map(\.id))
        for b in file.saneReports where !haveReports.contains(b.id) {
            guard let r = try? JSONDecoder().decode(TeacherReport.self, from: b.json) else { continue }
            let s = StoredReport(title: b.title, created: b.created, report: r.sanitized(knownExerciseIds: Set(ExerciseCatalog.all(ctx).keys)))
            s.id = b.id
            s.appliedAt = b.appliedAt
            ctx.insert(s)
        }
        if let st = file.settings { restoreSettings(st) }
        try ctx.save()
        return new.count
    }

    /// Settings only fill in what this install does not have yet (never overwrite a fresh calibration).
    private static func restoreSettings(_ st: BackupSettings) {
        for (k, d) in st.levelHistory { if let level = Int(k), (1...8).contains(level) { SettingsStore.markLevelReached(level, at: d) } }
        for mode in InputMode.allCases where SettingsStore.latency(for: mode) == 0 {
            if let ms = st.latencyMs[mode.rawValue], ms.isFinite, abs(ms) < 1_000 { SettingsStore.setLatency(ms / 1000, for: mode) }
        }
        if SettingsStore.midiMap().isEmpty {
            SettingsStore.saveMidiMap(Dictionary(uniqueKeysWithValues: st.midiMap.compactMap { k, v in
                UInt8(k).flatMap { n in DrumCore.Voice(rawValue: v).map { (n, $0) } } }))
        }
        if SettingsStore.currentGrade == 0, (0...8).contains(st.currentGrade) { SettingsStore.currentGrade = st.currentGrade }
        if let data = st.teacherProfile, data.count < 200_000, let p = try? JSONDecoder().decode(StudentProfile.self, from: data),
           TeacherConnection.profile == StudentProfile() { TeacherConnection.profile = p }
    }

    /// Weekly automatic backup into Documents/Backups (visible in the Files app). Keeps the last 8.
    static func autoBackupIfDue(_ ctx: ModelContext, now: Date = Date()) {
        let key = "lastAutoBackup"
        let last = UserDefaults.standard.object(forKey: key) as? Date ?? .distantPast
        guard now.timeIntervalSince(last) >= 7 * 86_400 else { return }
        let dir = URL.documentsDirectory.appending(path: "Backups")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? backup(ctx).encoded() else { return }
        try? data.write(to: dir.appending(path: BackupFile.fileName(for: now)))
        UserDefaults.standard.set(now, forKey: key)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for old in files.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).dropFirst(8) { try? FileManager.default.removeItem(at: old) }
    }
}
