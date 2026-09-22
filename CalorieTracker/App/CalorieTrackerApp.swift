import SwiftUI
import SwiftData

@main
struct CalorieTrackerApp: App {
    let modelContainer: ModelContainer
    @State private var userDataStore: UserDataStore
    @State private var sessionStore: SessionStore
    @State private var localization = LocalizationStore()

    init() {
        let schema = Schema([ProfileRecord.self, DayLogRecord.self, MealRecord.self, SavedProductRecord.self])
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
        self.modelContainer = container

        let dataStore = UserDataStore(context: container.mainContext)
        _userDataStore = State(initialValue: dataStore)
        _sessionStore = State(initialValue: SessionStore(userDataStore: dataStore))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionStore)
                .environment(userDataStore)
                .environment(localization)
                .modelContainer(modelContainer)
        }
    }
}
