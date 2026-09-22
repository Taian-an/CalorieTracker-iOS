import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh-Hant"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zh: return "繁體中文"
        case .en: return "English"
        }
    }
}

/// In-app language switch (Profile → App Settings → Language), independent of the system
/// locale — matches calorie-app's `LanguageContext.js`. Unlike the RN app (which resets to
/// 'zh' on every relaunch), this persists the choice via UserDefaults, a small deliberate
/// improvement rather than a bug to replicate.
@Observable
@MainActor
final class LocalizationStore {
    private static let storageKey = "app.language"

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey), let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .zh
        }
    }

    func t(_ key: String) -> String {
        Strings.table[key]?[language] ?? key
    }
}
