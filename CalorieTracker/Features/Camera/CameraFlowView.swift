import SwiftUI
import PhotosUI

/// Capture/upload → describe → analyze → review → explicit save flow, matching camera.js.
/// Nothing is logged until the user taps Save.
struct CameraFlowView: View {
    let mealType: MealType
    let autoPickLibrary: Bool
    let dateKey: String

    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var description = ""
    @State private var isAnalyzing = false
    @State private var result: AnalyzeResultDTO?
    @State private var errorMessage: String?
    @State private var isSaved = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var shownEnergy: Double = 0

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    resultView(result)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                } else if let capturedImage {
                    reviewView(capturedImage)
                        .transition(.opacity)
                } else {
                    CameraCaptureView { image in capturedImage = image }
                        .ignoresSafeArea()
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: result)
            .sensoryFeedback(.success, trigger: result) { _, new in new != nil }
            .sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }
            .navigationTitle(localization.t("camera.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.cancel")) { dismiss() }
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        capturedImage = image
                    }
                }
            }
            .onAppear {
                if autoPickLibrary && capturedImage == nil { showPhotoPicker = true }
            }
        }
    }

    private func reviewView(_ image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay { if isAnalyzing { AnalyzingOverlay(label: localization.t("camera.analyzing")) } }
                    .animation(.easeInOut(duration: 0.3), value: isAnalyzing)

                TextField(localization.t("camera.describe"), text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(Theme.danger)
                }

                HStack(spacing: 12) {
                    Button(localization.t("camera.retake")) {
                        capturedImage = nil
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await analyze(image) }
                    } label: {
                        if isAnalyzing {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(localization.t("camera.analyze")).frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzing)
                }
            }
            .padding(20)
        }
    }

    private func resultView(_ result: AnalyzeResultDTO) -> some View {
        let goal = userData.profile.target ?? 2000
        let alreadyEaten = userData.dayTotals(dateKey).energy
        let remaining = goal - alreadyEaten - result.energy

        return ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text(result.name).font(.title2.bold())
                    Text("\(Int(result.grams))g · " + localization.t("diary.\(mealType.rawValue)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // counts up from 0 to the result so the number "lands" instead of just appearing
                Text("\(Int(shownEnergy)) " + localization.t("common.kcal"))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: shownEnergy))
                    .onAppear {
                        withAnimation(.spring(response: 0.9, dampingFraction: 0.9).delay(0.15)) { shownEnergy = result.energy }
                    }

                HStack(spacing: 20) {
                    macroPill(localization.t("diary.protein"), result.protein, Theme.protein)
                    macroPill(localization.t("diary.carbs"), result.carbs, Theme.carbs)
                    macroPill(localization.t("diary.fat"), result.fat, Theme.fat)
                }

                if result.items.count > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(result.items.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(Int(item.grams))g · \(Int(item.calories)) " + localization.t("common.kcal"))
                                    .monospacedDigit()
                            }
                            .staggeredAppear(index: index + 2)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }

                Text(localization.t("camera.remaining") + ": \(Int(remaining)) " + localization.t("common.kcal"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if isSaved {
                    Label(localization.t("camera.saved"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                        .font(.headline)
                        .symbolEffect(.bounce, value: isSaved)
                        .transition(.scale.combined(with: .opacity))

                    Button(localization.t("common.done")) { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                } else {
                    Button(localization.t("camera.save")) { save(result) }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isSaved)
        }
        .sensoryFeedback(.success, trigger: isSaved) { _, saved in saved }
    }

    private func macroPill(_ label: String, _ grams: Double, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(grams))g").font(.headline).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func analyze(_ image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            result = try await AnalyzeAPI.analyze(image: image, description: description)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ result: AnalyzeResultDTO) {
        let meal = MealEntryDTO(
            name: result.name,
            energy: result.energy,
            protein: result.protein,
            carbs: result.carbs,
            fat: result.fat,
            mealType: mealType,
            time: Date().timeIntervalSince1970 * 1000,
            grams: result.grams
        )
        userData.addMeal(date: dateKey, meal: meal)
        isSaved = true
    }
}

/// Shown over the photo while the AI works: dimmed photo, a scan line sweeping top to bottom,
/// and a pulsing sparkle — makes the 3–4 s wait feel like progress rather than a frozen screen.
private struct AnalyzingOverlay: View {
    let label: String
    @State private var sweep = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.35)
                LinearGradient(colors: [.clear, Theme.calorie.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 70)
                    .offset(y: sweep ? geometry.size.height / 2 : -geometry.size.height / 2)
                    .blendMode(.plusLighter)
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .semibold))
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    Text(label).font(.headline)
                }
                .foregroundStyle(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { sweep = true }
        }
    }
}
