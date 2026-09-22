import Foundation

enum AuthAPI {
    static func register(email: String, username: String, password: String, name: String?) async throws -> AuthResponseDTO {
        var profile: [String: String]?
        if let name, !name.isEmpty { profile = ["name": name] }
        let body = RegisterRequest(email: email, username: username, password: password, profile: profile)
        return try await APIClient.shared.request("/auth/register", method: .post, body: body)
    }

    static func login(email: String, password: String) async throws -> AuthResponseDTO {
        let body = LoginRequest(email: email, password: password)
        return try await APIClient.shared.request("/auth/login", method: .post, body: body)
    }

    static func loginWithGoogle(idToken: String) async throws -> AuthResponseDTO {
        let body = GoogleLoginRequest(idToken: idToken)
        return try await APIClient.shared.request("/auth/google", method: .post, body: body)
    }
}

enum ProfileAPI {
    static func fetchMe() async throws -> ProfileDTO {
        try await APIClient.shared.request("/me", method: .get, auth: .required)
    }

    /// Sends a `ProfileDTO` as a partial patch: the compiler-synthesized `Encodable` conformance
    /// omits `nil` optional fields from the JSON body, so only the fields you set are updated —
    /// the server's PUT /me whitelists to PROFILE_FIELDS regardless.
    static func update(_ patch: ProfileDTO) async throws -> ProfileDTO {
        try await APIClient.shared.request("/me", method: .put, body: patch, auth: .required)
    }
}
