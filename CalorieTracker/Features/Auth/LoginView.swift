import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LocalizationStore.self) private var localization

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.calorie)
                    Text(localization.t("auth.loginTitle"))
                        .font(.largeTitle.bold())
                }
                .padding(.top, 40)

                VStack(spacing: 14) {
                    TextField(localization.t("auth.email"), text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField(localization.t("auth.password"), text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        showForgotAlert = true
                    } label: {
                        Text(localization.t("auth.forgotPassword"))
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Button {
                    Task { await login() }
                } label: {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(localization.t("auth.loginButton")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || isLoading)

                if AppConfig.googleIOSClientID != nil {
                    HStack {
                        VStack { Divider() }
                        Text(localization.t("auth.or")).font(.caption).foregroundStyle(.secondary)
                        VStack { Divider() }
                    }
                    GoogleSignInButton { idToken in
                        await loginWithGoogle(idToken)
                    }
                }

                NavigationLink(localization.t("auth.noAccount") + " " + localization.t("auth.registerButton")) {
                    RegisterView()
                }
                .font(.footnote)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Theme.screenBackground)
        .alert(localization.t("auth.forgotPassword"), isPresented: $showForgotAlert) {
            Button(localization.t("common.ok"), role: .cancel) {}
        } message: {
            Text(localization.t("auth.forgotAlert"))
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await session.login(email: email, password: password)
        } catch {
            errorMessage = localization.message(for: error, unauthorizedKey: "error.wrongCredentials")
        }
    }

    private func loginWithGoogle(_ idToken: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await session.loginWithGoogle(idToken: idToken)
        } catch {
            errorMessage = localization.message(for: error, unauthorizedKey: "error.googleFailed")
        }
    }
}
