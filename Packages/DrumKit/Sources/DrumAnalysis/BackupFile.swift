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

    public func newSessions(existing: Set<UUID>) -> [BackupSession] { sessions.filter { !existing.contains($0.id) } }

    public static func fileName(for date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return "DrumCoach-backup-\(f.string(from: date)).json"
    }
}
