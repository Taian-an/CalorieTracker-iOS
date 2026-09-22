import SwiftUI

enum FoodCaptureSource {
    case camera
    case library
    case packaged
}

struct AddFoodSheet: View {
    let mealType: MealType
    let onSelect: (FoodCaptureSource) -> Void

    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Button {
                    onSelect(.camera)
                } label: {
                    Label(localization.t("diary.scanFood"), systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onSelect(.library)
                } label: {
                    Label(localization.t("diary.uploadImage"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)

                Button {
                    onSelect(.packaged)
                } label: {
                    Label(localization.t("diary.searchPackaged"), systemImage: "barcode.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(24)
            .navigationTitle(localization.t("diary.addFood"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.cancel")) { dismiss() }
                }
            }
        }
        .presentationDetents([.height(330)])
    }
}
