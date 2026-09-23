import SwiftUI

struct ProfileView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(SessionStore.self) private var session
    @Environment(LocalizationStore.self) private var localization

    @State private var showEditProfile = false
    @State private var showFeedback = false
    @State private var infoModal: HealthMetric?
    @State private var showComingSoonAlert = false

    private var profile: ProfileDTO { userData.profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    statCards
                    personalInfoCard
                    accountCard
                    settingsCard
                    Text(localization.t("profile.version"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
                .padding(16)
            }
            .background(Theme.screenBackground)
            .navigationTitle(localization.t("tab.profile"))
            .task { await userData.refreshProfileFromServer() }
            .sheet(isPresented: $showEditProfile) { EditProfileSheet() }
            .sheet(isPresented: $showFeedback) { FeedbackSheet() }
            .sheet(item: $infoModal) { metric in HealthMetricInfoSheet(metric: metric) }
            .alert(localization.t("profile.comingSoon"), isPresented: $showComingSoonAlert) {
                Button(localization.t("common.ok"), role: .cancel) {}
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 10) {
            AvatarView(avatarKey: profile.avatarKey, size: 84)
            Text(profile.name?.isEmpty == false ? profile.name! : (profile.username ?? ""))
                .font(.title3.bold())
            Text(bioLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(localization.t("profile.editProfile")) { showEditProfile = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var bioLine: String {
        var parts: [String] = []
        if let age = profile.age { parts.append("\(Int(age))") }
        if let gender = profile.gender { parts.append(localization.t(gender == .male ? "onboarding.male" : "onboarding.female")) }
        if let height = profile.height { parts.append("\(Int(height))cm") }
        if let weight = profile.weight { parts.append("\(Int(weight))kg") }
        return parts.joined(separator: " · ")
    }

    private var statCards: some View {
        HStack(spacing: 12) {
            statCard(.bmi)
            statCard(.tdee)
            statCard(.bmr)
        }
    }

    private func statCard(_ metric: HealthMetric) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(metric.title(localization))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { infoModal = metric } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(metric.formattedValue(profile))
                .font(.headline)
                .foregroundStyle(metric.valueColor(profile))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private var personalInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(localization.t("profile.personalInfo")).font(.headline).padding(.bottom, 8)
            infoRow(localization.t("profile.gender"), profile.gender.map { localization.t($0 == .male ? "onboarding.male" : "onboarding.female") } ?? "—")
            infoRow(localization.t("profile.age"), profile.age.map { "\(Int($0))" } ?? "—")
            infoRow(localization.t("profile.height"), profile.height.map { "\(Int($0)) cm" } ?? "—")
            infoRow(localization.t("profile.weight"), profile.weight.map { "\(Int($0)) kg" } ?? "—")
            infoRow(localization.t("profile.activity"), profile.activity.map { localization.t("activity.\($0.rawValue)") } ?? "—", isLast: true)
        }
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture { showEditProfile = true }
    }

    private func infoRow(_ label: String, _ value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value)
            }
            .font(.subheadline)
            .padding(.vertical, 8)
            if !isLast { Divider() }
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.t("profile.accountSync")).font(.headline)
            if let email = session.authEmail {
                Text(email).font(.subheadline)
                Text(localization.t("profile.loggedIn"))
                    .font(.caption)
                    .foregroundStyle(Theme.success)
            }
            Button(role: .destructive) {
                session.logout()
            } label: {
                Text(localization.t("profile.logout")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .cardStyle()
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(localization.t("profile.appSettings")).font(.headline).padding(.bottom, 8)

            HStack {
                Text(localization.t("profile.language"))
                Spacer()
                HStack(spacing: 6) {
                    ForEach(AppLanguage.allCases) { lang in
                        let isSelected = localization.language == lang
                        Button {
                            localization.language = lang
                        } label: {
                            Text(lang.displayName)
                                .font(.footnote.weight(isSelected ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? Theme.calorie : Theme.cardBackground, in: Capsule())
                                .foregroundStyle(isSelected ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 8)
            Text(localization.t("profile.languageHint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            Divider()

            ForEach(["profile.appearance", "profile.notifications", "profile.units", "profile.privacy", "profile.about"], id: \.self) { key in
                Button { showComingSoonAlert = true } label: {
                    HStack {
                        Text(localization.t(key))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                }
                .foregroundStyle(.primary)
                Divider()
            }

            Button { showFeedback = true } label: {
                HStack {
                    Text(localization.t("profile.sendFeedback"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
            }
            .foregroundStyle(.primary)
        }
        .cardStyle()
    }
}
