import SwiftUI
import VisionKit

/// Live barcode scanning with VisionKit's `DataScannerViewController` on devices that support it,
/// plus a manual-entry fallback — the Simulator has no camera, so the fallback is also what makes
/// the feature demoable there.
struct BarcodeScannerSheet: View {
    let onBarcode: (String) -> Void

    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss
    @State private var manualCode = ""
    @FocusState private var fieldFocused: Bool

    /// Coca-Cola 330 ml can — a product known to be complete in Open Food Facts.
    private static let exampleBarcode = "5449000000996"

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if scannerAvailable {
                    DataScannerRepresentable { code in
                        submit(code)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(ScanFrameOverlay())
                    .frame(maxHeight: 360)
                } else {
                    Label(localization.t("lookup.scannerUnavailable"), systemImage: "camera.metering.unknown")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .cardStyle()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(localization.t("lookup.manualEntry")).font(.headline)
                    HStack {
                        TextField(localization.t("lookup.manualPlaceholder"), text: $manualCode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .focused($fieldFocused)
                            .onSubmit { submit(manualCode) }
                        Button(localization.t("lookup.lookUp")) { submit(manualCode) }
                            .buttonStyle(.borderedProminent)
                            .disabled(manualCode.filter(\.isNumber).count < 8)
                    }
                    Button {
                        manualCode = Self.exampleBarcode
                        submit(Self.exampleBarcode)
                    } label: {
                        Label(localization.t("lookup.tryExample"), systemImage: "wand.and.stars")
                            .font(.footnote)
                    }
                }
                .cardStyle()

                Spacer()
            }
            .padding(20)
            .background(Theme.screenBackground)
            .navigationTitle(localization.t("lookup.scan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.cancel")) { dismiss() }
                }
            }
            .onAppear { if !scannerAvailable { fieldFocused = true } }
        }
    }

    private func submit(_ code: String) {
        let digits = code.filter(\.isNumber)
        guard !digits.isEmpty else { return }
        dismiss()
        onBarcode(digits)
    }
}

/// Target frame + sweeping line drawn over the live camera feed.
private struct ScanFrameOverlay: View {
    @State private var sweep = false

    var body: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 36
            let rect = geometry.frame(in: .local).insetBy(dx: inset, dy: geometry.size.height * 0.28)
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: rect.width, height: rect.height)
                Capsule()
                    .fill(LinearGradient(colors: [.clear, Theme.calorie, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: rect.width - 16, height: 3)
                    .offset(y: sweep ? rect.height / 2 - 8 : -rect.height / 2 + 8)
                    .shadow(color: Theme.calorie, radius: 6)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { sweep = true }
        }
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onBarcode: onBarcode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        private var didReport = false

        init(onBarcode: @escaping (String) -> Void) { self.onBarcode = onBarcode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didReport else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    didReport = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onBarcode(payload)
                    return
                }
            }
        }
    }
}
