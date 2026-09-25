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
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
            Self.applySystemLanguage(language)
        }
    }

    /// Dates, weekday letters and number formats follow this instead of the phone's locale.
    /// Injected at the root as `\.locale`, so `Text(date, format:)` picks it up automatically.
    var locale: Locale { Locale(identifier: language.rawValue) }

    /// Value sent to the backend so AI-generated text (food names, coach replies) matches the UI.
    var apiLanguageCode: String { language == .en ? "en" : "zh" }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey), let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            // First launch defaults to English; the language menu on the login screen and in
            // Profile lets the user switch to 繁體中文, and that choice is saved.
            language = .en
        }
        Self.applySystemLanguage(language)
    }

    /// Text drawn by iOS itself — permission prompts, the search bar's Cancel, photo picker, share
    /// sheets — comes from the app's *system* language, which can't change while the app runs.
    /// Setting AppleLanguages makes those follow the in-app choice from the next launch on.
    private static func applySystemLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }

    func t(_ key: String) -> String {
        Strings.table[key]?[language] ?? key
    }

    /// User-facing text for any error from our backend or the network. Raw server messages are never
    /// shown directly — some are hard-coded in one language on the server, and system network errors
    /// follow the phone's language — so each known case maps to a translated string instead.
    /// `unauthorizedKey` lets a screen give 401 its own meaning (on Login it means a wrong password).
    func message(for error: Error, unauthorizedKey: String = "error.unauthorized") -> String {
        guard let apiError = error as? APIError else { return t("error.generic") }
        switch apiError {
        case .transport(let underlying):
            if (underlying as? URLError)?.code == .timedOut { return t("error.timeout") }
            return t("error.network")
        case .unauthorized:
            return t(unauthorizedKey)
        case .decodingFailed, .encodingFailed, .invalidURL:
            return t("error.server")
        case .server(let status, let message):
            switch (status, message) {
            case (409, "Email already registered"): return t("error.emailTaken")
            case (409, "Username already taken"): return t("error.usernameTaken")
            case (400, let m) where m.hasPrefix("Invalid email, username or password"): return t("error.invalidRegister")
            case (_, "No food data found"): return t("error.noFood")
            case (504, _): return t("error.timeout")
            case (429, _): return t("error.rateLimited")
            case (500..., _): return t("error.server")
            default: return t("error.generic")
            }
        }
    }
}
