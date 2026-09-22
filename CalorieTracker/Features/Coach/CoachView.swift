import SwiftUI

/// Placeholder tab — no chat logic or backend endpoint exists yet, matching coach.js exactly.
struct CoachView: View {
    @Environment(LocalizationStore.self) private var localization

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("🤖").font(.system(size: 64))
                Text(localization.t("coach.title"))
                    .font(.title2.bold())
                Text(localization.t("coach.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.screenBackground)
        }
    }
}
