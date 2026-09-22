import SwiftUI

struct CameraLaunchContext: Identifiable {
    let mealType: MealType
    let autoPickLibrary: Bool
    var id: String { mealType.rawValue + (autoPickLibrary ? "-lib" : "-cam") }
}

struct DiaryView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization

    @State private var selectedDate = Date()
    @State private var showCalendar = false
    @State private var showAdjustGoal = false
    @State private var addFoodMealType: MealType?
    @State private var cameraContext: CameraLaunchContext?
    @State private var lookupMealType: MealType?

    private var dateKey: String { DateKey.string(for: selectedDate) }
    private var totals: (energy: Double, protein: Double, carbs: Double, fat: Double) { userData.dayTotals(dateKey) }
    private var goal: Double { userData.profile.target ?? 2000 }
    private var macroTargets: HealthCalculations.MacroTargets { HealthCalculations.macroTargets(forCalorieGoal: goal) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WeekStrip(selectedDate: $selectedDate, hasLog: { date in
                        !userData.dayLog(DateKey.string(for: date)).meals.isEmpty
                    })
                    .cardStyle()

                    VStack(spacing: 16) {
                        CalorieRing(eaten: totals.energy, goal: goal)
                            .frame(width: 160, height: 160)

                        HStack(spacing: 24) {
                            statLabel(localization.t("diary.eaten"), value: totals.energy)
                            statLabel(localization.t("diary.goal"), value: goal)
                            statLabel(localization.t("diary.left"), value: max(goal - totals.energy, 0))
                        }

                        VStack(spacing: 10) {
                            MacroBar(label: localization.t("diary.protein"), color: Theme.protein, current: totals.protein, target: macroTargets.proteinGrams)
                            MacroBar(label: localization.t("diary.carbs"), color: Theme.carbs, current: totals.carbs, target: macroTargets.carbsGrams)
                            MacroBar(label: localization.t("diary.fat"), color: Theme.fat, current: totals.fat, target: macroTargets.fatGrams)
                        }
                    }
                    .cardStyle()
                    .overlay(alignment: .topTrailing) {
                        Button { showAdjustGoal = true } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }

                    ForEach(MealType.allCases) { mealType in
                        MealSectionView(
                            mealType: mealType,
                            meals: userData.meals(dateKey, type: mealType),
                            goalCalories: goal,
                            onAdd: { addFoodMealType = mealType },
                            onDelete: { time in
                                withAnimation(.snappy) { userData.removeMeal(date: dateKey, time: time) }
                            }
                        )
                    }
                }
                .padding(16)
                // switching days slides the whole diary content instead of snapping
                .id(dateKey)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 12)), removal: .opacity))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: dateKey)
            .background(Theme.screenBackground)
            .navigationTitle(selectedDate.formatted(.dateTime.month(.wide).day()))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCalendar = true } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showCalendar) {
                DiaryCalendarSheet(selectedDate: $selectedDate)
            }
            .sheet(isPresented: $showAdjustGoal) {
                AdjustGoalSheet()
            }
            .sheet(item: $addFoodMealType) { mealType in
                AddFoodSheet(mealType: mealType) { source in
                    addFoodMealType = nil
                    if source == .packaged {
                        lookupMealType = mealType
                    } else {
                        cameraContext = CameraLaunchContext(mealType: mealType, autoPickLibrary: source == .library)
                    }
                }
            }
            .sheet(item: $lookupMealType) { mealType in
                FoodLookupView(presetMealType: mealType, dateKey: dateKey, isSheet: true)
            }
            .fullScreenCover(item: $cameraContext) { context in
                CameraFlowView(mealType: context.mealType, autoPickLibrary: context.autoPickLibrary, dateKey: dateKey)
            }
        }
    }

    private func statLabel(_ title: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(Int(value), format: .number)
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText(value: value))
                .animation(.snappy, value: value)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
