import SwiftUI

/// Three-tier gate, matching `_layout.js`'s `Stack.Protected` guards:
/// not signed in → auth; signed in but not onboarded → onboarding; else → tabs.
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(UserDataStore.self) private var userData

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
        .animation(.default, value: session.isAuthenticated)
        .animation(.default, value: userData.profile.isOnboarded)
    }
}
