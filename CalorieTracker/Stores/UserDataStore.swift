import Foundation
import SwiftData
import Observation

/// Offline-first store for the signed-in user's profile and daily logs.
///
/// Mirrors `context/UserDataContext.js`: every mutation writes to SwiftData immediately
/// (optimistic, local-first), then fires a best-effort background sync to the server.
/// Sync failures are logged, never surfaced to the UI or retried — same as the RN app.
@Observable
@MainActor
final class UserDataStore {
    private(set) var profile = ProfileDTO()
    private(set) var dailyLogs: [String: DayLogDTO] = [:]

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        loadFromDisk()
    }

    // MARK: - Loading

    private func loadFromDisk() {
        if let record = try? context.fetch(FetchDescriptor<ProfileRecord>()).first {
            profile = record.asDTO
        }
        if let records = try? context.fetch(FetchDescriptor<DayLogRecord>()) {
            dailyLogs = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0.asDTO) })
        }
    }

    private func profileRecord() -> ProfileRecord {
        if let existing = try? context.fetch(FetchDescriptor<ProfileRecord>()).first {
            return existing
        }
        let record = ProfileRecord()
        context.insert(record)
        return record
    }

    private func dayLogRecord(for date: String) -> DayLogRecord {
        let target = date
        let descriptor = FetchDescriptor<DayLogRecord>(predicate: #Predicate { $0.date == target })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let record = DayLogRecord(date: date)
        context.insert(record)
        return record
    }

    private func save() {
        try? context.save()
    }

    // MARK: - Auth lifecycle

    /// Full replace (not merge) on login/register, matching `applyAuthResult` in UserDataContext.js —
    /// deliberately avoids leaking a previous account's cached data into a newly-signed-in account.
    func replaceProfile(_ dto: ProfileDTO) {
        let record = profileRecord()
        record.apply(dto)
        save()
        profile = record.asDTO
    }

    func replaceLogs(_ logs: LogsResponse) {
        let existing = (try? context.fetch(FetchDescriptor<DayLogRecord>())) ?? []
        for record in existing { context.delete(record) }
        for (date, dto) in logs {
            let record = DayLogRecord(date: date, weight: dto.weight, target: dto.target)
            record.meals = dto.meals.map { MealRecord($0) }
            context.insert(record)
        }
        save()
        dailyLogs = logs
    }

    func clearLogs() {
        let existing = (try? context.fetch(FetchDescriptor<DayLogRecord>())) ?? []
        for record in existing { context.delete(record) }
        save()
        dailyLogs = [:]
    }

    func clearAll() {
        let profiles = (try? context.fetch(FetchDescriptor<ProfileRecord>())) ?? []
        for record in profiles { context.delete(record) }
        // Recent/favorite packaged foods are per-person too — don't show them to the next account
        let products = (try? context.fetch(FetchDescriptor<SavedProductRecord>())) ?? []
        for record in products { context.delete(record) }
        clearLogs()
        profile = ProfileDTO()
    }

    func refreshLogsFromServer() async {
        guard let logs = try? await LogsAPI.fetchLogs() else { return }
        replaceLogs(logs)
    }

    func refreshProfileFromServer() async {
        guard let dto = try? await ProfileAPI.fetchMe() else { return }
        let record = profileRecord()
        record.apply(dto)
        save()
        profile = record.asDTO
    }

    // MARK: - Profile mutation

    /// Merges non-nil fields from `patch` into the current profile, persists locally, then
    /// fire-and-forget syncs to PUT /me.
    func updateProfile(_ patch: ProfileDTO) {
        let record = profileRecord()
        if let v = patch.name { record.name = v }
        if let v = patch.avatarKey { record.avatarKey = v }
        if let v = patch.gender { record.gender = v }
        if let v = patch.age { record.age = v }
        if let v = patch.height { record.height = v }
        if let v = patch.weight { record.weight = v }
        if let v = patch.activity { record.activity = v }
        if let v = patch.goal { record.goal = v }
        if let v = patch.bmr { record.bmr = v }
        if let v = patch.tdee { record.tdee = v }
        if let v = patch.target { record.target = v }
        save()
        profile = record.asDTO

        // Also stamp today's log with the latest weight/target, matching updateProfile() in
        // UserDataContext.js (today's weight and calorie target travel with the day's log).
        if patch.weight != nil || patch.target != nil {
            let today = DateKey.today()
            let log = dayLogRecord(for: today)
            if let w = patch.weight { log.weight = w }
            if let t = patch.target { log.target = t }
            save()
            dailyLogs[today] = log.asDTO
        }

        Task { try? await ProfileAPI.update(patch) }
    }

    // MARK: - Log queries

    func dayLog(_ date: String) -> DayLogDTO {
        dailyLogs[date] ?? .empty
    }

    func dayTotals(_ date: String) -> (energy: Double, protein: Double, carbs: Double, fat: Double) {
        let meals = dayLog(date).meals
        return meals.reduce((0, 0, 0, 0)) { acc, meal in
            (acc.0 + meal.energy, acc.1 + meal.protein, acc.2 + meal.carbs, acc.3 + meal.fat)
        }
    }

    func meals(_ date: String, type: MealType) -> [MealEntryDTO] {
        dayLog(date).meals.filter { $0.mealType == type }.sorted { $0.time < $1.time }
    }

    // MARK: - Log mutation

    func addMeal(date: String, meal: MealEntryDTO) {
        let record = dayLogRecord(for: date)
        record.meals.append(MealRecord(meal))
        save()
        dailyLogs[date] = record.asDTO
        syncLog(date: date)
    }

    func removeMeal(date: String, time: Double) {
        let record = dayLogRecord(for: date)
        if let match = record.meals.first(where: { $0.time == time }) {
            context.delete(match)
            record.meals.removeAll { $0.time == time }
        }
        save()
        dailyLogs[date] = record.asDTO
        syncLog(date: date)
    }

    private func syncLog(date: String) {
        guard let dto = dailyLogs[date] else { return }
        Task { try? await LogsAPI.putLog(date: date, log: dto) }
    }
}
