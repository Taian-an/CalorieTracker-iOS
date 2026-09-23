import SwiftUI

struct AuthFlowView: View {
    @Environment(LocalizationStore.self) private var localization

    var body: some View {
        NavigationStack {
            LoginView()
                .toolbar {
                    // Language can be changed before signing in, not only from Profile
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker(localization.t("profile.language"), selection: Bindable(localization).language) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                        } label: {
                            Label(localization.language.displayName, systemImage: "globe")
                                .labelStyle(.titleAndIcon)
                                .font(.subheadline)
                        }
                    }
                }
        }
    }
}
