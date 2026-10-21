import Foundation

public struct BackupSession: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let date: Date
    public let exerciseId: String
    public let title: String
    public let skill: String
    public let bpm: Double
    public let seconds: Double
    public let mode: String
    public let goodWindowMs: Double
    public let stats: SessionStats
    public let isLevelTest: Bool
    public let levelTestId: String?
    /// Encoded `Assessment` JSON, kept opaque here.
    public let assessment: Data?

    public init(id: UUID, date: Date, exerciseId: String, title: String, skill: String, bpm: Double, seconds: Double, mode: String,
                goodWindowMs: Double, stats: SessionStats, isLevelTest: Bool, levelTestId: String?, assessment: Data?) {
        self.id = id
        self.date = date
        self.exerciseId = exerciseId
        self.title = title
        self.skill = skill
        self.bpm = bpm
        self.seconds = seconds
        self.mode = mode
        self.goodWindowMs = goodWindowMs
        self.stats = stats
        self.isLevelTest = isLevelTest
        self.levelTestId = levelTestId
        self.assessment = assessment
    }
}

extension BackupSession {
    /// Every number finite and within the ranges the app can produce; strings short.
    var isSane: Bool {
        let s = stats
        let finite = [bpm, seconds, goodWindowMs, s.score, s.accuracy, s.meanOffsetMs, s.stdDevMs] + Array(s.byBeatPosition.values)
            + Array(s.byVoice.values) + Array(s.byHand.values) + Array(s.loudnessByHandDb.values) + [s.velocityCV ?? 0, s.accentContrastDb ?? 0]
        return finite.allSatisfy(\.isFinite)
            && (20...400).contains(bpm) && (0...86_400).contains(seconds) && (1...200).contains(goodWindowMs)
            && (0...100).contains(s.score) && (0...1).contains(s.accuracy) && (0...1_000_000).contains(s.totalNotes)
            && finite.allSatisfy { abs($0) <= 100_000 }
            && [title, skill, exerciseId, mode].allSatisfy { $0.count <= 500 } && (levelTestId?.count ?? 0) <= 100
            && date.timeIntervalSince1970 > 0 && date.timeIntervalSinceNow < 86_400
    }
}

public struct BackupJournal: Codable, Sendable, Equatable {
    public let id: UUID
    public let date: Date
    public let text: String
    public init(id: UUID, date: Date, text: String) { self.id = id; self.date = date; self.text = text }
}

/// Whole practice history as one JSON file (Files / Notion backup, restore after reinstall).
public struct BackupFile: Codable, Sendable, Equatable {
    public static let currentVersion = 1
    public let version: Int
    public let exportedAt: Date
    public let sessions: [BackupSession]
    public let journal: [BackupJournal]

    public init(exportedAt: Date, sessions: [BackupSession], journal: [BackupJournal]) {
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.sessions = sessions
        self.journal = journal
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> BackupFile {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(BackupFile.self, from: data)
    }

    /// Sessions not yet in the store, dropping any with out-of-range values (a crafted file must not crash the app).
    public func newSessions(existing: Set<UUID>) -> [BackupSession] {
        Array(sessions.lazy.filter { !existing.contains($0.id) && $0.isSane }.prefix(Self.maxSessions))
    }

    /// Journal notes with a reasonable length.
    public var saneJournal: [BackupJournal] { Array(journal.filter { $0.text.count <= 10_000 }.prefix(Self.maxSessions)) }

    static let maxSessions = 200_000

    public static func fileName(for date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return "DrumCoach-backup-\(f.string(from: date)).json"
    }
}
