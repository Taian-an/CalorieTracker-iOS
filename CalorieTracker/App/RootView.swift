import SwiftUI

/// Three-tier gate, matching `_layout.js`'s `Stack.Protected` guards:
/// not signed in → auth; signed in but not onboarded → onboarding; else → tabs.
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization

    var body: some View {
        Group {
            if !session.isAuthenticated {
                AuthFlowView()
            } else if !userData.profile.isOnboarded {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        // dates / weekday letters / number formatting follow the in-app language, not the phone's
        .environment(\.locale, localization.locale)
        .animation(.default, value: session.isAuthenticated)
        .animation(.default, value: userData.profile.isOnboarded)
    }
}
