import Foundation
import Synchronization

/// Languages the app ships in.
public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case vi, en

    /// The device's first preferred language decides: Vietnamese → `.vi`, anything else → `.en`.
    public static func systemDefault(preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        preferred.first?.lowercased().hasPrefix("vi") == true ? .vi : .en
    }
}

/// The app's current language. Set from Settings; tests and previews can scope an `override` per task.
public enum Lang {
    private static let storage = Mutex(AppLanguage.systemDefault())
    @TaskLocal public static var override: AppLanguage?

    public static var current: AppLanguage {
        get { override ?? storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}

/// Picks the Vietnamese or English text for the current language.
public func L(_ vi: String, _ en: String) -> String { Lang.current == .vi ? vi : en }
