import SwiftUI

struct MealSectionView: View {
    let mealType: MealType
    let meals: [MealEntryDTO]
    let goalCalories: Double
    let onAdd: () -> Void
    let onDelete: (Double) -> Void

    @Environment(LocalizationStore.self) private var localization
    @State private var isExpanded = true

    private var totalEnergy: Double { meals.reduce(0) { $0 + $1.energy } }
    private var target: Double { goalCalories * mealType.goalShare }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(Theme.calorie)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.t("diary.\(mealType.rawValue)")).font(.headline)
                        Text("\(Int(totalEnergy)) / \(Int(target)) " + localization.t("common.kcal"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.calorie)
                    }
                    .buttonStyle(PressableButtonStyle())
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if meals.isEmpty {
                    Text(localization.t("diary.noMeals"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 8) {
                        ForEach(meals) { meal in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meal.name).font(.subheadline)
                                    Text("P \(Int(meal.protein))g · C \(Int(meal.carbs))g · F \(Int(meal.fat))g")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(meal.energy)) " + localization.t("common.kcal"))
                                    .font(.subheadline)
                                Button {
                                    onDelete(meal.time)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
        .cardStyle()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: meals.map(\.id))
        .sensoryFeedback(.impact(weight: .light), trigger: meals.count)
    }

    private var icon: String {
        switch mealType {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snacks: return "carrot.fill"
        }
    }
}
