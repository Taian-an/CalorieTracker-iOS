import Foundation

/// Central place for environment-specific configuration.
enum AppConfig {
    /// Local dev server, matches `calorie-app/.env.local`'s active `EXPO_PUBLIC_API_URL`.
    static let localAPIBaseURL = URL(string: "http://localhost:3000")!

    /// Deployed production server, matches `deploy.sh`'s `PROD_API_URL`.
    static let productionAPIBaseURL = URL(string: "https://20-46-181-25.nip.io/api")!

    /// Debug builds hit the local dev server; Release builds hit production.
    static var apiBaseURL: URL {
        #if DEBUG
        return localAPIBaseURL
        #else
        return productionAPIBaseURL
        #endif
    }

    /// Not configured yet — no iOS OAuth client exists in Google Cloud Console for this app
    /// (server/.env and calorie-app/.env.local both leave GOOGLE_IOS_CLIENT_ID blank).
    /// Once you create one (Console → APIs & Services → Credentials → iOS client), paste its
    /// client ID here and the Google sign-in button becomes visible automatically.
    static let googleIOSClientID: String? = nil

    static let networkTimeout: TimeInterval = 20
}
