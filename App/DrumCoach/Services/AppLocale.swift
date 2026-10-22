import DrumCore
import Foundation

/// The language picked in Settings ("system", "vi" or "en") and the locale used for dates and numbers.
enum AppLocale {
    static let key = "appLanguage"

    static func language(for choice: String) -> AppLanguage {
        AppLanguage(rawValue: choice) ?? AppLanguage.systemDefault()
    }

    /// Applies the choice to `Lang` (used by every `L(vi, en)`) and returns it, so the root view can be rebuilt with it.
    @discardableResult
    static func apply(_ choice: String) -> String {
        Lang.current = language(for: choice)
        return choice
    }

    static var current: Locale { Locale(identifier: Lang.current == .vi ? "vi_VN" : "en_US") }
}
