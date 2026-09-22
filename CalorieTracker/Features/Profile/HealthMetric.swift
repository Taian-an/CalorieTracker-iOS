import SwiftUI

enum HealthMetric: String, Identifiable {
    case bmi, tdee, bmr
    var id: String { rawValue }

    @MainActor
    func title(_ localization: LocalizationStore) -> String {
        localization.t("profile.\(rawValue)")
    }

    func formattedValue(_ profile: ProfileDTO) -> String {
        switch self {
        case .bmi:
            guard let w = profile.weight, let h = profile.height else { return "—" }
            return String(format: "%.1f", HealthCalculations.bmi(weightKg: w, heightCm: h))
        case .tdee:
            return profile.tdee.map { "\(Int($0))" } ?? "—"
        case .bmr:
            return profile.bmr.map { "\(Int($0))" } ?? "—"
        }
    }

    func valueColor(_ profile: ProfileDTO) -> Color {
        guard self == .bmi, let w = profile.weight, let h = profile.height else { return .primary }
        switch HealthCalculations.bmiCategory(HealthCalculations.bmi(weightKg: w, heightCm: h)) {
        case .underweight: return .blue
        case .normal: return Theme.success
        case .overweight: return .orange
        case .obese: return Theme.danger
        }
    }
}

struct HealthMetricInfoSheet: View {
    let metric: HealthMetric
    @Environment(\.dismiss) private var dismiss
    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization

    private var profile: ProfileDTO { userData.profile }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                switch metric {
                case .bmi:
                    Text("BMI = weight(kg) ÷ height(m)²").font(.callout)
                    if let w = profile.weight, let h = profile.height {
                        let bmi = HealthCalculations.bmi(weightKg: w, heightCm: h)
                        Text("= \(w, specifier: "%.1f") ÷ (\(h / 100, specifier: "%.2f"))² = \(bmi, specifier: "%.1f")")
                            .font(.callout.monospaced())
                        Text(localization.t(HealthCalculations.bmiCategory(bmi).localizedTitleKey))
                            .font(.headline)
                    }
                case .bmr:
                    Text(localization.t("profile.bmrFormula")).font(.callout)
                    if let g = profile.gender {
                        Text(g == .male
                             ? "88.362 + 13.397×weight + 4.799×height − 5.677×age"
                             : "447.593 + 9.247×weight + 3.098×height − 4.330×age")
                            .font(.footnote.monospaced())
                    }
                    if let bmr = profile.bmr {
                        Text("= \(Int(bmr)) kcal/day").font(.headline)
                    }
                case .tdee:
                    Text(localization.t("profile.tdeeFormula")).font(.callout)
                    if let bmr = profile.bmr, let activity = profile.activity {
                        Text("\(Int(bmr)) × \(activity.factor, specifier: "%.3f") = \(Int(HealthCalculations.tdee(bmr: bmr, activity: activity))) kcal/day")
                            .font(.footnote.monospaced())
                    }
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle(metric.title(localization))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.t("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
