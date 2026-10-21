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

@Test func versionTwoCarriesUserData() throws {
    let ex = BackupExercise(id: UUID(), title: "Bài sách", dsl: "title: A\ntime: 4/4\ngrid: 1\nSN: xxxx", source: "Sách của tôi",
                            tags: [], favorite: true, createdAt: Date(timeIntervalSince1970: 1_790_000_000))
    let rep = BackupReport(id: UUID(), title: "Kế hoạch 2026-10-20", created: Date(timeIntervalSince1970: 1_790_000_000),
                           json: Data("{}".utf8), appliedAt: Date(timeIntervalSince1970: 1_790_000_500))
    let settings = BackupSettings(levelHistory: ["1": Date(timeIntervalSince1970: 1_790_000_000)], latencyMs: ["pad": 42],
                                  midiMap: ["38": "snare"], currentGrade: 1, teacherProfile: Data("{}".utf8))
    let file = BackupFile(exportedAt: Date(timeIntervalSince1970: 1_790_000_100), sessions: [], journal: [],
                          exercises: [ex], reports: [rep], settings: settings)
    let back = try BackupFile.decode(file.encoded())
    #expect(back == file)
    #expect(back.version == 2)
}

@Test func versionOneFilesStillImport() throws {
    let v1 = #"{"version":1,"exportedAt":"2026-09-21T00:00:00Z","sessions":[],"journal":[]}"#
    let f = try BackupFile.decode(Data(v1.utf8))
    #expect(f.exercises.isEmpty && f.reports.isEmpty && f.settings == nil)
}

@Test func invalidExercisesAreNotRestored() {
    let bad = BackupExercise(id: UUID(), title: "x", dsl: "garbage", source: "U", tags: [], favorite: false, createdAt: Date(timeIntervalSince1970: 1))
    let good = BackupExercise(id: UUID(), title: "y", dsl: "title: A\ntime: 4/4\ngrid: 1\nSN: xxxx", source: "U", tags: [], favorite: false, createdAt: Date(timeIntervalSince1970: 1))
    let f = BackupFile(exportedAt: Date(), sessions: [], journal: [], exercises: [bad, good], reports: [], settings: nil)
    #expect(f.saneExercises.map(\.title) == ["y"])
}
