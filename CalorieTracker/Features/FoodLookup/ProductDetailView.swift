import SwiftUI
import SwiftData

/// One Open Food Facts product: pick a portion, see the totals update live, favorite it, log it.
/// Opening this screen saves/refreshes the product in SwiftData (it becomes "Recently Viewed").
struct ProductDetailView: View {
    let product: OFFProduct
    var presetMealType: MealType?
    var dateKey: String?
    /// Set when shown inside the diary's Add Food sheet — closes the sheet after logging.
    var onLogged: (() -> Void)?

    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization
    @Environment(\.modelContext) private var modelContext

    @State private var grams: Double
    @State private var mealType: MealType
    @State private var record: SavedProductRecord?
    @State private var addedCount = 0
    @State private var showAddedBadge = false

    init(product: OFFProduct, presetMealType: MealType? = nil, dateKey: String? = nil, onLogged: (() -> Void)? = nil) {
        self.product = product
        self.presetMealType = presetMealType
        self.dateKey = dateKey
        self.onLogged = onLogged
        _grams = State(initialValue: (product.servingGrams ?? 100).rounded())
        _mealType = State(initialValue: presetMealType ?? .inferred())
    }

    private var factor: Double { grams / 100 }
    private var n: OFFNutriments { product.nutriments }
    private var kcal: Double { (n.kcal ?? 0) * factor }
    private var protein: Double { (n.protein ?? 0) * factor }
    private var carbs: Double { (n.carbs ?? 0) * factor }
    private var fat: Double { (n.fat ?? 0) * factor }
    private var isFavorite: Bool { record?.isFavorite ?? false }
    private var sliderMax: Double { max(500, ((product.servingGrams ?? 100) * 4).rounded(.up)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                totalsCard
                portionCard
                per100Card
                mealPicker
            }
            .padding(16)
            .padding(.bottom, 90) // room for the floating add button
        }
        .background(Theme.screenBackground)
        .navigationTitle("") // name + brand are already in the header card; long brand strings crowd the bar
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? .pink : .primary)
                        .symbolEffect(.bounce, value: isFavorite)
                        .contentTransition(.symbolEffect(.replace))
                }
                .sensoryFeedback(.impact(weight: .light), trigger: isFavorite)
            }
        }
        .safeAreaInset(edge: .bottom) { addButton }
        .overlay { if showAddedBadge { addedBadge } }
        .sensoryFeedback(.success, trigger: addedCount)
        .onAppear(perform: saveToRecents)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 16) {
            ProductThumbnail(url: product.imageURL, size: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name).font(.title3.bold())
                if let brand = product.brand {
                    Text(brand).font(.subheadline).foregroundStyle(.secondary)
                }
                Label(product.code, systemImage: "barcode")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var totalsCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(kcal.rounded()))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: kcal))
                    .foregroundStyle(Theme.calorie)
                Text(localization.t("common.kcal")).font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                macroTile(localization.t("diary.protein"), protein, Theme.protein)
                macroTile(localization.t("diary.carbs"), carbs, Theme.carbs)
                macroTile(localization.t("diary.fat"), fat, Theme.fat)
            }
            MacroSplitBar(protein: protein, carbs: carbs, fat: fat)
        }
        .animation(.snappy, value: grams)
        .cardStyle()
    }

    private func macroTile(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value, format: .number.precision(.fractionLength(1)))
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText(value: value))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var portionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localization.t("lookup.portion")).font(.headline)
                Spacer()
                Text("\(Int(grams)) \(localization.t("lookup.grams"))")
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText(value: grams))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let serving = product.servingGrams {
                        portionChip(localization.t("lookup.serving") + " · \(Int(serving.rounded())) g", serving)
                    }
                    ForEach([30.0, 50, 100, 200], id: \.self) { value in
                        portionChip("\(Int(value)) g", value)
                    }
                }
            }
            Slider(value: $grams, in: 5...sliderMax, step: 5)
                .tint(Theme.calorie)
                .sensoryFeedback(.selection, trigger: Int(grams / 25))
        }
        .cardStyle()
    }

    private func portionChip(_ title: String, _ value: Double) -> some View {
        let selected = abs(grams - value.rounded()) < 0.5
        return Button {
            withAnimation(.snappy) { grams = value.rounded() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Theme.calorie : Theme.calorie.opacity(0.12), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.snappy, value: selected)
    }

    private var per100Card: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.t("lookup.per100g")).font(.headline)
            nutrientRow(localization.t("common.kcal"), n.kcal, unit: "kcal")
            nutrientRow(localization.t("diary.protein"), n.protein, unit: "g")
            nutrientRow(localization.t("diary.carbs"), n.carbs, unit: "g")
            nutrientRow(localization.t("lookup.sugar"), n.sugar, unit: "g", indent: true)
            nutrientRow(localization.t("diary.fat"), n.fat, unit: "g")
            nutrientRow(localization.t("lookup.fiber"), n.fiber, unit: "g")
            nutrientRow(localization.t("lookup.sodium"), n.sodium.map { $0 * 1000 }, unit: "mg")
        }
        .cardStyle()
    }

    private func nutrientRow(_ label: String, _ value: Double?, unit: String, indent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(indent ? .footnote : .subheadline)
                .foregroundStyle(indent ? .secondary : .primary)
                .padding(.leading, indent ? 14 : 0)
            Spacer()
            Text(value.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(unit)" } ?? "—")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.t("lookup.mealType")).font(.headline)
            Picker(localization.t("lookup.mealType"), selection: $mealType) {
                ForEach(MealType.allCases) { type in
                    Text(localization.t("diary.\(type.rawValue)")).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .cardStyle()
    }

    private var addButton: some View {
        Button(action: addToLog) {
            Label(localization.t("lookup.addToLog") + " · \(Int(kcal.rounded())) kcal", systemImage: "plus.circle.fill")
                .font(.headline)
                .contentTransition(.numericText(value: kcal))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Theme.calorie, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.calorie.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var addedBadge: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.success)
                .symbolEffect(.bounce, value: addedCount)
            Text(localization.t("lookup.added")).font(.headline)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    // MARK: - Actions

    /// Upserts the product in SwiftData so it shows under "Recently Viewed" and opens offline next time.
    private func saveToRecents() {
        let code = product.code
        let descriptor = FetchDescriptor<SavedProductRecord>(predicate: #Predicate { $0.barcode == code })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: product)
            record = existing
        } else {
            let new = SavedProductRecord(product)
            modelContext.insert(new)
            record = new
        }
        try? modelContext.save()
    }

    private func toggleFavorite() {
        guard let record else { return }
        withAnimation(.spring) { record.isFavorite.toggle() }
        try? modelContext.save()
    }

    private func addToLog() {
        let meal = MealEntryDTO(
            name: product.brand.map { "\(product.name) (\($0))" } ?? product.name,
            energy: kcal.rounded(),
            protein: (protein * 10).rounded() / 10,
            carbs: (carbs * 10).rounded() / 10,
            fat: (fat * 10).rounded() / 10,
            mealType: mealType,
            time: Date().timeIntervalSince1970 * 1000,
            grams: grams
        )
        userData.addMeal(date: dateKey ?? DateKey.string(for: Date()), meal: meal)
        addedCount += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showAddedBadge = true }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(.easeOut(duration: 0.25)) { showAddedBadge = false }
            try? await Task.sleep(for: .seconds(0.25))
            onLogged?()
        }
    }
}

/// Proportion of calories coming from protein / carbs / fat, animating as the portion changes.
private struct MacroSplitBar: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    var body: some View {
        let p = protein * 4, c = carbs * 4, f = fat * 9
        let total = max(p + c + f, 0.0001)
        GeometryReader { geometry in
            HStack(spacing: 2) {
                Capsule().fill(Theme.protein).frame(width: geometry.size.width * p / total)
                Capsule().fill(Theme.carbs).frame(width: geometry.size.width * c / total)
                Capsule().fill(Theme.fat).frame(width: geometry.size.width * f / total)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }
}
