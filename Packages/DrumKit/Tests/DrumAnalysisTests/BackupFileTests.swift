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
