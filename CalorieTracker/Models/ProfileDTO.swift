import Foundation

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
}

enum Goal: String, Codable, CaseIterable, Identifiable {
    case bulk, cut, maintain
    var id: String { rawValue }

    /// kcal/day offset applied to TDEE to get the daily calorie target.
    var calorieDelta: Double {
        switch self {
        case .bulk: return 300
        case .cut: return -400
        case .maintain: return 0
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case lightly
    case moderately
    case very
    case extra

    var id: String { rawValue }

    /// Mirrors the activity factors in calorie-app's onboarding.js.
    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightly: return 1.375
        case .moderately: return 1.55
        case .very: return 1.725
        case .extra: return 1.9
        }
    }
}

/// Matches the server's `publicProfile()` shape from server.js: PROFILE_FIELDS + email/username.
struct ProfileDTO: Codable, Equatable {
    var email: String?
    var username: String?
    var name: String?
    var avatarKey: String?
    var gender: Gender?
    var age: Double?
    var height: Double?
    var weight: Double?
    var activity: ActivityLevel?
    var goal: Goal?
    var bmr: Double?
    var tdee: Double?
    var target: Double?

    var isOnboarded: Bool { height != nil }
}
