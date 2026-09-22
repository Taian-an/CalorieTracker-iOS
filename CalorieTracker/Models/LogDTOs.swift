import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snacks
    var id: String { rawValue }

    /// Share of the daily calorie goal, mirrors calorie-app's diary screen.
    var goalShare: Double {
        switch self {
        case .breakfast: return 0.25
        case .lunch: return 0.30
        case .dinner: return 0.29
        case .snacks: return 0.16
        }
    }

    /// Default meal type inferred from time-of-day, mirrors camera.js.
    static func inferred(from date: Date = Date()) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<10: return .breakfast
        case 10..<15: return .lunch
        case 15..<21: return .dinner
        default: return .snacks
        }
    }
}

/// Matches one entry in DailyLog.meals on the server.
struct MealEntryDTO: Codable, Equatable, Identifiable {
    var name: String
    var energy: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var mealType: MealType
    var time: Double
    var grams: Double?

    var id: Double { time }
}

/// Matches one value in the GET /logs dictionary, and the PUT /logs/:date body.
struct DayLogDTO: Codable, Equatable {
    var weight: Double?
    var target: Double?
    var meals: [MealEntryDTO]

    static let empty = DayLogDTO(weight: nil, target: nil, meals: [])
}

typealias LogsResponse = [String: DayLogDTO]
