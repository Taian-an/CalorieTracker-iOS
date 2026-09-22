import Foundation
import Observation

/// Tracks whether the user is signed in and orchestrates auth calls, handing the resulting
/// profile/logs off to `UserDataStore`. The JWT itself lives in the Keychain, never here.
@Observable
@MainActor
final class SessionStore {
    private(set) var isAuthenticated: Bool
    private(set) var authEmail: String?

    private let userDataStore: UserDataStore

    init(userDataStore: UserDataStore) {
        self.userDataStore = userDataStore
        self.isAuthenticated = KeychainStore.loadToken() != nil
        self.authEmail = userDataStore.profile.email
    }

    func register(email: String, username: String, password: String, name: String?) async throws {
        let result = try await AuthAPI.register(email: email, username: username, password: password, name: name)
        // Matches register() in UserDataContext.js: no /logs fetch, local logs reset to empty.
        applyAuthResult(result)
        userDataStore.clearLogs()
    }

    func login(email: String, password: String) async throws {
        let result = try await AuthAPI.login(email: email, password: password)
        applyAuthResult(result)
        await userDataStore.refreshLogsFromServer()
    }

    func loginWithGoogle(idToken: String) async throws {
        let result = try await AuthAPI.loginWithGoogle(idToken: idToken)
        applyAuthResult(result)
        await userDataStore.refreshLogsFromServer()
    }

    private func applyAuthResult(_ result: AuthResponseDTO) {
        KeychainStore.saveToken(result.token)
        userDataStore.replaceProfile(result.profile)
        authEmail = result.profile.email
        isAuthenticated = true
    }

    func logout() {
        KeychainStore.clearToken()
        userDataStore.clearAll()
        authEmail = nil
        isAuthenticated = false
    }
}
