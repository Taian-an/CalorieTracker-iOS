import Foundation
import SwiftData

/// The local, offline-first source of truth for the signed-in user's profile.
/// There is exactly one row at a time (the app clears/replaces it on login/logout),
/// mirroring `UserDataContext.js`'s single `profile` object kept in AsyncStorage.
@Model
final class ProfileRecord {
    var email: String?
    var username: String?
    var name: String?
    var avatarKey: String?
    var genderRaw: String?
    var age: Double?
    var height: Double?
    var weight: Double?
    var activityRaw: String?
    var goalRaw: String?
    var bmr: Double?
    var tdee: Double?
    var target: Double?

    init() {}

    var gender: Gender? {
        get { genderRaw.flatMap(Gender.init(rawValue:)) }
        set { genderRaw = newValue?.rawValue }
    }

    var activity: ActivityLevel? {
        get { activityRaw.flatMap(ActivityLevel.init(rawValue:)) }
        set { activityRaw = newValue?.rawValue }
    }

    var goal: Goal? {
        get { goalRaw.flatMap(Goal.init(rawValue:)) }
        set { goalRaw = newValue?.rawValue }
    }

    var isOnboarded: Bool { height != nil }

    func apply(_ dto: ProfileDTO) {
        email = dto.email
        username = dto.username
        name = dto.name
        avatarKey = dto.avatarKey
        gender = dto.gender
        age = dto.age
        height = dto.height
        weight = dto.weight
        activity = dto.activity
        goal = dto.goal
        bmr = dto.bmr
        tdee = dto.tdee
        target = dto.target
    }

    var asDTO: ProfileDTO {
        ProfileDTO(
            email: email, username: username, name: name, avatarKey: avatarKey,
            gender: gender, age: age, height: height, weight: weight,
            activity: activity, goal: goal, bmr: bmr, tdee: tdee, target: target
        )
    }
}
