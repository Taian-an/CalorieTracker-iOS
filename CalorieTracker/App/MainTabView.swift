import SwiftUI

struct MainTabView: View {
    @Environment(LocalizationStore.self) private var localization

    var body: some View {
        TabView {
            DiaryView()
                .tabItem { Label(localization.t("tab.diary"), systemImage: "book.closed.fill") }

            FoodLookupView()
                .tabItem { Label(localization.t("tab.lookup"), systemImage: "barcode.viewfinder") }

            ProgressScreenView()
                .tabItem { Label(localization.t("tab.progress"), systemImage: "chart.bar.fill") }

            CoachView()
                .tabItem { Label(localization.t("tab.coach"), systemImage: "bubble.left.and.bubble.right.fill") }

            ProfileView()
                .tabItem { Label(localization.t("tab.profile"), systemImage: "person.fill") }
        }
        .tint(Theme.calorie)
    }
}
