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

    /// iOS OAuth client registered in Google Cloud Console for bundle ID `com.taian.calorietracker.app`
    /// ("Calorie iOS Native"). Client IDs aren't secrets — iOS clients have no client secret.
    /// The server must list it in GOOGLE_IOS_CLIENT_ID or it rejects the resulting id_token.
    static let googleIOSClientID: String? = "714318056157-o184lk87ld7gblsbvllihercisioidcl.apps.googleusercontent.com"

    static let networkTimeout: TimeInterval = 20
}
