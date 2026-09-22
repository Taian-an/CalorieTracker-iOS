import SwiftUI
import AuthenticationServices
import CryptoKit

/// Google sign-in via `ASWebAuthenticationSession` (no third-party GoogleSignIn SDK) — posts the
/// resulting `id_token` to `POST /auth/google`. Hidden unless `AppConfig.googleIOSClientID` is
/// configured, mirroring `GoogleAuthButton.js`'s own conditional rendering.
///
/// Google's iOS OAuth clients only support the authorization-code flow with PKCE (the implicit
/// `response_type=id_token` flow is rejected), so this runs the code flow and then exchanges the
/// code at the token endpoint — iOS clients have no secret, the PKCE verifier proves it's us.
struct GoogleSignInButton: View {
    var onToken: (String) async -> Void

    @Environment(LocalizationStore.self) private var localization
    @State private var contextProvider = WebAuthContextProvider()
    @State private var session: ASWebAuthenticationSession?

    var body: some View {
        if let clientID = AppConfig.googleIOSClientID {
            Button {
                startSignIn(clientID: clientID)
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text(localization.t("auth.continueWithGoogle"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func startSignIn(clientID: String) {
        // Google accepts the app's bundle ID as the redirect scheme for an iOS client registered with
        // that bundle ID; ASWebAuthenticationSession intercepts it, so no Info.plist URL type is needed.
        let scheme = Bundle.main.bundleIdentifier ?? "com.taian.calorietracker.app"
        let redirectURI = "\(scheme):/oauth2redirect"
        let verifier = Self.randomURLSafeString()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded()
        let state = Self.randomURLSafeString()

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let authURL = components.url else { return }

        let authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, _ in
            guard let callbackURL,
                  let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
                  items.first(where: { $0.name == "state" })?.value == state,
                  let code = items.first(where: { $0.name == "code" })?.value
            else { return }
            Task {
                if let idToken = await Self.exchange(code: code, clientID: clientID, redirectURI: redirectURI, verifier: verifier) {
                    await onToken(idToken)
                }
            }
        }
        authSession.presentationContextProvider = contextProvider
        authSession.start()
        session = authSession // keep a strong reference while the sheet is up
    }

    private static func exchange(code: String, clientID: String, redirectURI: String, verifier: String) async -> String? {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        struct TokenResponse: Decodable { let id_token: String? }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let response = try? JSONDecoder().decode(TokenResponse.self, from: data)
        else { return nil }
        return response.id_token
    }

    private static func randomURLSafeString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }
}

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
