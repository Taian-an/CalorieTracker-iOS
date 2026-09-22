import SwiftUI

struct OnboardingView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(OnboardingViewModel.Step.allCases.firstIndex(of: viewModel.step) ?? 0) + 1, total: Double(OnboardingViewModel.Step.allCases.count))
                .tint(Theme.calorie)
                .padding()

            if viewModel.isBuildingPlan {
                buildingPlanView
            } else {
                ScrollView {
                    stepContent
                        .padding(24)
                }

                HStack {
                    if viewModel.step != .gender {
                        Button(localization.t("common.back")) { viewModel.goBack() }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    Button(viewModel.isLastStep ? localization.t("onboarding.finish") : localization.t("common.next")) {
                        if viewModel.isLastStep {
                            finish()
                        } else {
                            viewModel.goNext()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .background(Theme.screenBackground)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .gender: genderStep
        case .age: ageStep
        case .height: heightStep
        case .currentWeight: currentWeightStep
        case .targetWeight: targetWeightStep
        case .duration: durationStep
        case .activity: activityStep
        }
    }

    private var genderStep: some View {
        VStack(spacing: 20) {
            Text(localization.t("onboarding.genderTitle")).font(.title2.bold())
            HStack(spacing: 16) {
                ForEach(Gender.allCases) { gender in
                    let isSelected = viewModel.gender == gender
                    Button {
                        viewModel.gender = gender
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: gender == .male ? "figure.stand" : "figure.stand.dress")
                                .font(.system(size: 36))
                            Text(localization.t(gender == .male ? "onboarding.male" : "onboarding.female"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(isSelected ? Theme.calorie.opacity(0.15) : Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cardCornerRadius).strokeBorder(isSelected ? Theme.calorie : .clear, lineWidth: 2))
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var ageStep: some View {
        stepperCard(title: "onboarding.ageTitle", value: $viewModel.age, range: 13...100, step: 1, unit: "")
    }

    private var heightStep: some View {
        stepperCard(title: "onboarding.heightTitle", value: $viewModel.heightCm, range: 100...230, step: 1, unit: "cm")
    }

    private var currentWeightStep: some View {
        VStack(spacing: 16) {
            stepperCard(title: "onboarding.weightTitle", value: $viewModel.weightKg, range: 30...250, step: 0.5, unit: "kg")
            HStack {
                Text("BMI")
                Spacer()
                Text(viewModel.bmi, format: .number.precision(.fractionLength(1)))
                    .fontWeight(.semibold)
            }
            .cardStyle()
        }
    }

    private var targetWeightStep: some View {
        VStack(spacing: 16) {
            stepperCard(title: "onboarding.targetWeightTitle", value: $viewModel.targetWeightKg, range: 30...250, step: 0.5, unit: "kg")
            HStack {
                Text(localization.t("progress.weightChange"))
                Spacer()
                Text(viewModel.weightDeltaKg, format: .number.precision(.fractionLength(1)).sign(strategy: .always()))
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.weightDeltaKg > 0 ? Theme.success : Theme.danger)
            }
            .cardStyle()
        }
    }

    private var durationStep: some View {
        VStack(spacing: 20) {
            Text(localization.t("onboarding.durationTitle")).font(.title2.bold())
            HStack(spacing: 10) {
                ForEach([1, 3, 6, 12], id: \.self) { months in
                    let isSelected = viewModel.durationMonths == months
                    Button {
                        viewModel.durationMonths = months
                    } label: {
                        Text("\(months) " + localization.t("onboarding.months"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isSelected ? Theme.calorie : Theme.cardBackground, in: Capsule())
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                }
            }
        }
    }

    private var activityStep: some View {
        VStack(spacing: 12) {
            Text(localization.t("onboarding.activityTitle")).font(.title2.bold())
            ForEach(ActivityLevel.allCases) { level in
                let isSelected = viewModel.activity == level
                Button {
                    viewModel.activity = level
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localization.t("activity.\(level.rawValue)")).fontWeight(.semibold)
                        Text(localization.t("activity.\(level.rawValue).desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(isSelected ? Theme.calorie.opacity(0.15) : Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected ? Theme.calorie : .clear, lineWidth: 2))
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private func stepperCard(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        VStack(spacing: 20) {
            Text(localization.t(title)).font(.title2.bold())
            Text(unit.isEmpty ? "\(Int(value.wrappedValue))" : "\(value.wrappedValue, specifier: step < 1 ? "%.1f" : "%.0f") \(unit)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
    }

    private var buildingPlanView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text(localization.t("onboarding.buildingPlan"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func finish() {
        viewModel.isBuildingPlan = true
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            userData.updateProfile(viewModel.computeProfile())
        }
    }
}
