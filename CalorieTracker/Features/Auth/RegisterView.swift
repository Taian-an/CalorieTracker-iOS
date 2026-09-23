import SwiftUI

struct RegisterView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private var canSubmit: Bool {
        !email.isEmpty && !username.isEmpty && password.count >= 4 && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(localization.t("auth.registerTitle"))
                    .font(.largeTitle.bold())
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    TextField(localization.t("auth.firstName"), text: $firstName)
                        .textFieldStyle(.roundedBorder)
                    TextField(localization.t("auth.lastName"), text: $lastName)
                        .textFieldStyle(.roundedBorder)
                }

                TextField(localization.t("auth.email"), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                TextField(localization.t("auth.username"), text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField(localization.t("auth.password"), text: $password)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await register() }
                } label: {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(localization.t("auth.registerButton")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)

                if AppConfig.googleIOSClientID != nil {
                    GoogleSignInButton { idToken in
                        await Task {
                            do { try await session.loginWithGoogle(idToken: idToken) }
                            catch { errorMessage = localization.message(for: error, unauthorizedKey: "error.googleFailed") }
                        }.value
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.screenBackground)
        .navigationTitle(localization.t("auth.registerButton"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func register() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await session.register(email: email, username: username, password: password, name: fullName.isEmpty ? nil : fullName)
        } catch {
            errorMessage = localization.message(for: error)
        }
    }
}
