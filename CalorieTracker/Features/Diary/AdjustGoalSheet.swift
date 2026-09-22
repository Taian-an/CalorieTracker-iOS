import SwiftUI

struct AdjustGoalSheet: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss

    @State private var goal: Goal
    @State private var activity: ActivityLevel

    init() {
        _goal = State(initialValue: .maintain)
        _activity = State(initialValue: .sedentary)
    }

    private var bmr: Double { userData.profile.bmr ?? 0 }
    private var previewTDEE: Double { HealthCalculations.tdee(bmr: bmr, activity: activity) }
    private var previewTarget: Double { HealthCalculations.dailyCalorieTarget(tdee: previewTDEE, goal: goal) }

    var body: some View {
        NavigationStack {
            Form {
                Section(localization.t("diary.adjustGoal")) {
                    Picker(localization.t("diary.adjustGoal"), selection: $goal) {
                        ForEach(Goal.allCases) { g in
                            Text(localization.t("goal.\(g.rawValue)")).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(localization.t("profile.activity"), selection: $activity) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(localization.t("activity.\(level.rawValue)")).tag(level)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("TDEE")
                        Spacer()
                        Text(Int(previewTDEE), format: .number)
                    }
                    HStack {
                        Text(localization.t("diary.goal"))
                        Spacer()
                        Text(Int(previewTarget), format: .number)
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle(localization.t("diary.adjustGoal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.t("common.save")) { save() }
                }
            }
            .onAppear {
                goal = userData.profile.goal ?? .maintain
                activity = userData.profile.activity ?? .sedentary
            }
        }
    }

    private func save() {
        var patch = ProfileDTO()
        patch.goal = goal
        patch.activity = activity
        patch.tdee = previewTDEE
        patch.target = previewTarget
        userData.updateProfile(patch)
        dismiss()
    }
}
