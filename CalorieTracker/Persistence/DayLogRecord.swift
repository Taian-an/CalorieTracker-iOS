import Foundation
import SwiftData

/// One calendar day's log, keyed by "YYYY-MM-DD" (local calendar date — see DateKey.swift for why
/// this deliberately differs from the RN app's UTC-based `toISOString()` day key).
@Model
final class DayLogRecord {
    @Attribute(.unique) var date: String
    var weight: Double?
    var target: Double?

    @Relationship(deleteRule: .cascade, inverse: \MealRecord.dayLog)
    var meals: [MealRecord] = []

    init(date: String, weight: Double? = nil, target: Double? = nil) {
        self.date = date
        self.weight = weight
        self.target = target
    }

    var asDTO: DayLogDTO {
        DayLogDTO(weight: weight, target: target, meals: meals.sorted { $0.time < $1.time }.map(\.asDTO))
    }

    func apply(_ dto: DayLogDTO, context: ModelContext) {
        weight = dto.weight
        target = dto.target
        for meal in meals { context.delete(meal) }
        meals = dto.meals.map { MealRecord($0) }
    }
}

@Model
final class MealRecord {
    var name: String = ""
    var energy: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var mealTypeRaw: String = MealType.snacks.rawValue
    var time: Double = 0
    var grams: Double?

    var dayLog: DayLogRecord?

    init(name: String, energy: Double, protein: Double, carbs: Double, fat: Double, mealType: MealType, time: Double, grams: Double?) {
        self.name = name
        self.energy = energy
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.mealTypeRaw = mealType.rawValue
        self.time = time
        self.grams = grams
    }

    convenience init(_ dto: MealEntryDTO) {
        self.init(name: dto.name, energy: dto.energy, protein: dto.protein, carbs: dto.carbs, fat: dto.fat, mealType: dto.mealType, time: dto.time, grams: dto.grams)
    }

    /// Unknown/legacy meal types normalize to `.snacks`, matching UserDataContext.js.
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snacks }
        set { mealTypeRaw = newValue.rawValue }
    }

    var asDTO: MealEntryDTO {
        MealEntryDTO(name: name, energy: energy, protein: protein, carbs: carbs, fat: fat, mealType: mealType, time: time, grams: grams)
    }
}
