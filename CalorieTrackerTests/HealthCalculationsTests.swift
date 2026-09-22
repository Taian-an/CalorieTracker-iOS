import XCTest
@testable import CalorieTracker

final class HealthCalculationsTests: XCTestCase {
    func testBMRMale() {
        let bmr = HealthCalculations.bmr(gender: .male, weightKg: 70, heightCm: 175, age: 30)
        // 88.362 + 13.397*70 + 4.799*175 - 5.677*30
        XCTAssertEqual(bmr, 1695.667, accuracy: 0.01)
    }

    func testBMRFemale() {
        let bmr = HealthCalculations.bmr(gender: .female, weightKg: 60, heightCm: 165, age: 25)
        // 447.593 + 9.247*60 + 3.098*165 - 4.330*25
        XCTAssertEqual(bmr, 1405.333, accuracy: 0.01)
    }

    func testTDEE() {
        XCTAssertEqual(HealthCalculations.tdee(bmr: 1500, activity: .sedentary), 1800, accuracy: 0.01)
        XCTAssertEqual(HealthCalculations.tdee(bmr: 1500, activity: .extra), 2850, accuracy: 0.01)
    }

    func testInferGoal() {
        XCTAssertEqual(HealthCalculations.inferGoal(currentWeightKg: 70, targetWeightKg: 75), .bulk)
        XCTAssertEqual(HealthCalculations.inferGoal(currentWeightKg: 70, targetWeightKg: 65), .cut)
        XCTAssertEqual(HealthCalculations.inferGoal(currentWeightKg: 70, targetWeightKg: 70.1), .maintain)
    }

    func testDailyCalorieTarget() {
        XCTAssertEqual(HealthCalculations.dailyCalorieTarget(tdee: 2000, goal: .bulk), 2300)
        XCTAssertEqual(HealthCalculations.dailyCalorieTarget(tdee: 2000, goal: .cut), 1600)
        XCTAssertEqual(HealthCalculations.dailyCalorieTarget(tdee: 2000, goal: .maintain), 2000)
    }

    func testBMICategories() {
        XCTAssertEqual(HealthCalculations.bmiCategory(17), .underweight)
        XCTAssertEqual(HealthCalculations.bmiCategory(22), .normal)
        XCTAssertEqual(HealthCalculations.bmiCategory(25), .overweight)
        XCTAssertEqual(HealthCalculations.bmiCategory(30), .obese)
    }

    func testMacroTargets() {
        let targets = HealthCalculations.macroTargets(forCalorieGoal: 2000)
        XCTAssertEqual(targets.proteinGrams, 100, accuracy: 0.01)
        XCTAssertEqual(targets.carbsGrams, 250, accuracy: 0.01)
        XCTAssertEqual(targets.fatGrams, 66.67, accuracy: 0.1)
    }
}
