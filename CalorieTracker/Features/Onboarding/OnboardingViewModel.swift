import Foundation
import Observation

/// 7-step BMR/TDEE wizard state, ported from onboarding.js.
@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case gender, age, height, currentWeight, targetWeight, duration, activity
    }

    var step: Step = .gender

    var gender: Gender = .male
    var age: Double = 25
    var heightCm: Double = 170
    var weightKg: Double = 65
    var targetWeightKg: Double = 65
    var durationMonths: Int = 3
    var activity: ActivityLevel = .sedentary

    var isBuildingPlan = false

    var bmi: Double { HealthCalculations.bmi(weightKg: weightKg, heightCm: heightCm) }
    var weightDeltaKg: Double { targetWeightKg - weightKg }

    var canGoNext: Bool { true }
    var isLastStep: Bool { step == Step.allCases.last }

    func goNext() {
        guard let index = Step.allCases.firstIndex(of: step), index + 1 < Step.allCases.count else { return }
        step = Step.allCases[index + 1]
    }

    func goBack() {
        guard let index = Step.allCases.firstIndex(of: step), index > 0 else { return }
        step = Step.allCases[index - 1]
    }

    /// Computes the resulting profile fields, matching onboarding.js's finish handler.
    func computeProfile() -> ProfileDTO {
        let goal = HealthCalculations.inferGoal(currentWeightKg: weightKg, targetWeightKg: targetWeightKg)
        let bmr = HealthCalculations.bmr(gender: gender, weightKg: weightKg, heightCm: heightCm, age: age)
        let tdee = HealthCalculations.tdee(bmr: bmr, activity: activity)
        let target = HealthCalculations.dailyCalorieTarget(tdee: tdee, goal: goal)

        var profile = ProfileDTO()
        profile.gender = gender
        profile.age = age
        profile.height = heightCm
        profile.weight = weightKg
        profile.activity = activity
        profile.bmr = bmr
        profile.tdee = tdee
        profile.goal = goal
        profile.target = target
        return profile
    }
}
