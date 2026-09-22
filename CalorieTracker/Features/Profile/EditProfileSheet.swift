import SwiftUI

struct EditProfileSheet: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss

    @State private var avatarKey = BuiltInAvatar.default.rawValue
    @State private var name = ""
    @State private var gender: Gender = .male
    @State private var age: Double = 25
    @State private var height: Double = 170
    @State private var weight: Double = 65
    @State private var activity: ActivityLevel = .sedentary

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ForEach(BuiltInAvatar.allCases) { avatar in
                            Button {
                                avatarKey = avatar.rawValue
                            } label: {
                                AvatarView(avatarKey: avatar.rawValue, size: 48)
                                    .overlay {
                                        if avatarKey == avatar.rawValue {
                                            Circle().strokeBorder(Theme.calorie, lineWidth: 3)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Section {
                    TextField(localization.t("auth.firstName"), text: $name)

                    Picker(localization.t("profile.gender"), selection: $gender) {
                        ForEach(Gender.allCases) { g in
                            Text(localization.t(g == .male ? "onboarding.male" : "onboarding.female")).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper("\(localization.t("profile.age")): \(Int(age))", value: $age, in: 13...100)
                    Stepper("\(localization.t("profile.height")): \(Int(height)) cm", value: $height, in: 100...230)
                    Stepper("\(localization.t("profile.weight")): \(weight, specifier: "%.1f") kg", value: $weight, in: 30...250, step: 0.5)
                }

                Section(localization.t("profile.activity")) {
                    ForEach(ActivityLevel.allCases) { level in
                        Button {
                            activity = level
                        } label: {
                            HStack {
                                Text(localization.t("activity.\(level.rawValue)"))
                                Spacer()
                                if activity == level {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.calorie)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle(localization.t("profile.editProfile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.t("common.save")) { save() }
                }
            }
            .onAppear(perform: loadCurrentProfile)
        }
    }

    private func loadCurrentProfile() {
        let profile = userData.profile
        avatarKey = profile.avatarKey ?? BuiltInAvatar.default.rawValue
        name = profile.name ?? ""
        gender = profile.gender ?? .male
        age = profile.age ?? 25
        height = profile.height ?? 170
        weight = profile.weight ?? 65
        activity = profile.activity ?? .sedentary
    }

    /// Recomputes BMR/TDEE/target on save, preserving the existing goal — matches profile.js's
    /// edit-profile save handler.
    private func save() {
        let bmr = HealthCalculations.bmr(gender: gender, weightKg: weight, heightCm: height, age: age)
        let tdee = HealthCalculations.tdee(bmr: bmr, activity: activity)
        let goal = userData.profile.goal ?? .maintain
        let target = HealthCalculations.dailyCalorieTarget(tdee: tdee, goal: goal)

        var patch = ProfileDTO()
        patch.avatarKey = avatarKey
        patch.name = name
        patch.gender = gender
        patch.age = age
        patch.height = height
        patch.weight = weight
        patch.activity = activity
        patch.bmr = bmr
        patch.tdee = tdee
        patch.target = target
        userData.updateProfile(patch)
        dismiss()
    }
}
