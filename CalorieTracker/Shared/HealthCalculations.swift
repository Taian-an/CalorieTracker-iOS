import Foundation

/// Pure calculation functions, ported 1:1 from calorie-app's onboarding.js / profile.js so both
/// apps produce identical numbers for the same inputs. Kept side-effect-free and unit-tested.
enum HealthCalculations {
    /// Harris-Benedict BMR — note this is what calorie-app's onboarding.js actually implements,
    /// despite the project README claiming Mifflin-St Jeor.
    static func bmr(gender: Gender, weightKg: Double, heightCm: Double, age: Double) -> Double {
        switch gender {
        case .male:
            return 88.362 + 13.397 * weightKg + 4.799 * heightCm - 5.677 * age
        case .female:
            return 447.593 + 9.247 * weightKg + 3.098 * heightCm - 4.330 * age
        }
    }

    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.factor
    }

    /// bulk if target is meaningfully above current weight, cut if meaningfully below, else maintain.
    static func inferGoal(currentWeightKg: Double, targetWeightKg: Double) -> Goal {
        if targetWeightKg > currentWeightKg + 0.3 { return .bulk }
        if targetWeightKg < currentWeightKg - 0.3 { return .cut }
        return .maintain
    }

    static func dailyCalorieTarget(tdee: Double, goal: Goal) -> Double {
        tdee + goal.calorieDelta
    }

    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let heightM = heightCm / 100
        return weightKg / (heightM * heightM)
    }

    enum BMICategory: String {
        case underweight, normal, overweight, obese

        var localizedTitleKey: String {
            switch self {
            case .underweight: return "bmi.underweight"
            case .normal: return "bmi.normal"
            case .overweight: return "bmi.overweight"
            case .obese: return "bmi.obese"
            }
        }
    }

    static func bmiCategory(_ bmi: Double) -> BMICategory {
        switch bmi {
        case ..<18.5: return .underweight
        case 18.5..<24: return .normal
        case 24..<27: return .overweight
        default: return .obese
        }
    }

    /// Fixed 20% protein / 50% carbs / 30% fat split of the daily calorie goal, matching the
    /// diary screen's macro bars. Protein/carbs = 4 kcal/g, fat = 9 kcal/g.
    struct MacroTargets {
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
    }

    static func macroTargets(forCalorieGoal goal: Double) -> MacroTargets {
        MacroTargets(
            proteinGrams: (goal * 0.20) / 4,
            carbsGrams: (goal * 0.50) / 4,
            fatGrams: (goal * 0.30) / 9
        )
    }
}
