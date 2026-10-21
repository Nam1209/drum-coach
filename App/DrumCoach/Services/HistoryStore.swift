import DrumAnalysis
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
        return BackupFile(exportedAt: Date(), sessions: sessions, journal: notes)
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
        try ctx.save()
        return new.count
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
