import Foundation

/// The pages the teacher loop uses inside the user's DrumCoach page.
public struct NotionWorkspace: Equatable, Sendable {
    public let root: String
    public let rootTitle: String
    public let inbox: String
    public let plans: String
    public let exercises: String

    public init(root: String, rootTitle: String, inbox: String, plans: String, exercises: String) {
        self.root = root
        self.rootTitle = rootTitle
        self.inbox = inbox
        self.plans = plans
        self.exercises = exercises
    }
}

/// One-step connection: from just a token, find the page shared with the integration and set up its subpages.
public enum NotionSetup {
    public static let rootTitle = "DrumCoach"

    public struct Titles: Sendable {
        public let inbox: String, plans: String, exercises: String
        public init(inbox: String, plans: String, exercises: String) {
            self.inbox = inbox
            self.plans = plans
            self.exercises = exercises
        }
    }

    /// Picks the page titled "DrumCoach", otherwise the top page the user shared (whatever its name; its subpages from
    /// an earlier connect are skipped), then reuses or creates each subpage, so connecting again never makes duplicates.
    public static func connect(client: NotionClient, titles: Titles) async throws -> NotionWorkspace {
        let pages = try await client.searchPages()
        let ids = Set(pages.map(\.id))
        let named = pages.first { $0.title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(rootTitle) == .orderedSame }
        let top = pages.first { $0.parentPage.map { !ids.contains($0) } ?? true }
        guard let root = named ?? top else { throw NotionError.noSharedPage }
        let existing = try await client.childPages(of: root.id)
        func page(_ title: String) async throws -> String {
            if let found = existing.first(where: { $0.title == title }) { return found.id }
            return try await client.createChildPage(parent: root.id, title: title)
        }
        return NotionWorkspace(root: root.id, rootTitle: root.title.isEmpty ? rootTitle : root.title, inbox: try await page(titles.inbox), plans: try await page(titles.plans),
                               exercises: try await page(titles.exercises))
    }

    /// Writes the teacher's instructions as a page Claude reads through its Notion connector (replaces a Claude Project).
    @discardableResult
    public static func publishGuide(client: NotionClient, root: String, title: String, text: String) async throws -> String {
        for old in try await client.childPages(of: root) where old.title == title {
            try await client.archive(page: old.id)
        }
        return try await client.createChildPage(parent: root, title: title, codeBlockJSON: text, codeLanguage: "markdown")
    }
}
