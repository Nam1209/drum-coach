import Foundation
import Testing
@testable import DrumAnalysis

private func session(_ id: UUID = UUID(), score: Double = 80) -> BackupSession {
    BackupSession(id: id, date: Date(timeIntervalSince1970: 1_790_000_000), exerciseId: "A", title: "Bài A", skill: "R", bpm: 70,
                  seconds: 60, mode: "pad", goodWindowMs: 30, stats: eighthStats(andMs: 0), isLevelTest: false, levelTestId: nil, assessment: nil)
}

@Test func backupRoundTrip() throws {
    let file = BackupFile(exportedAt: Date(timeIntervalSince1970: 1_790_000_100), sessions: [session(), session()],
                          journal: [BackupJournal(id: UUID(), date: Date(timeIntervalSince1970: 1_790_000_000), text: "mỏi tay")])
    let back = try BackupFile.decode(file.encoded())
    #expect(back == file)
    #expect(back.version == BackupFile.currentVersion)
}

@Test func importSkipsExisting() {
    let a = session(), b = session()
    let file = BackupFile(exportedAt: Date(), sessions: [a, b], journal: [])
    #expect(file.newSessions(existing: [a.id]).map(\.id) == [b.id])
}

@Test func fileNameHasDate() {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
    #expect(BackupFile.fileName(for: Date(timeIntervalSince1970: 1_792_000_000), calendar: c) == "DrumCoach-backup-2026-10-14.json")
}

@Test func rejectsGarbage() {
    #expect(throws: (any Error).self) { try BackupFile.decode(Data("nope".utf8)) }
}

private func odd(bpm: Double = 70, seconds: Double = 60, window: Double = 30, title: String = "A") -> BackupSession {
    BackupSession(id: UUID(), date: Date(timeIntervalSince1970: 1_790_000_000), exerciseId: "A", title: title, skill: "R", bpm: bpm,
                  seconds: seconds, mode: "pad", goodWindowMs: window, stats: eighthStats(andMs: 0), isLevelTest: false, levelTestId: nil, assessment: nil)
}

@Test func importRejectsOutOfRangeValues() {
    let file = BackupFile(exportedAt: Date(), sessions: [odd(), odd(bpm: 1e300), odd(seconds: -5), odd(seconds: 1e12), odd(window: 9_999),
                                                          odd(title: String(repeating: "x", count: 5_000))], journal: [])
    #expect(file.newSessions(existing: []).count == 1)
}

@Test func importRejectsCraftedStats() throws {
    var json = String(data: try BackupFile(exportedAt: Date(), sessions: [odd()], journal: []).encoded(), encoding: .utf8)!
    json = json.replacingOccurrences(of: "\"meanOffsetMs\":0", with: "\"meanOffsetMs\":1e300")
    let file = try BackupFile.decode(Data(json.utf8))
    #expect(file.newSessions(existing: []).isEmpty)
}

@Test func importCapsJournalText() {
    let file = BackupFile(exportedAt: Date(), sessions: [], journal: [BackupJournal(id: UUID(), date: Date(), text: String(repeating: "y", count: 50_000))])
    #expect(file.saneJournal.isEmpty)
}
