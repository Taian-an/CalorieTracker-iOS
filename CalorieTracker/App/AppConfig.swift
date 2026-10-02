import Foundation

/// Central place for environment-specific configuration.
enum AppConfig {
    /// Deployed production server, matches `deploy.sh`'s `PROD_API_URL`.
    static let productionAPIBaseURL = URL(string: "https://app.calorietracks.com/api")!

    /// Every build — including Debug runs straight from Xcode — talks to production, so the app
    /// works out of the box without a local backend.
    ///
    /// To work against a local server instead, set an `API_BASE_URL` environment variable in
    /// Product → Scheme → Edit Scheme → Run → Arguments (e.g. `http://localhost:3000`).
    static var apiBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: override), url.scheme != nil {
            return url
        }
        return productionAPIBaseURL
    }

    /// iOS OAuth client registered in Google Cloud Console for bundle ID `com.taian.calorietracker.app`
    /// ("Calorie iOS Native"). Client IDs aren't secrets — iOS clients have no client secret.
    /// The server must list it in GOOGLE_IOS_CLIENT_ID or it rejects the resulting id_token.
    static let googleIOSClientID: String? = "714318056157-o184lk87ld7gblsbvllihercisioidcl.apps.googleusercontent.com"

    static let networkTimeout: TimeInterval = 20
}
