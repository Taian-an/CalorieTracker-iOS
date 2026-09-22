import SwiftUI
import SwiftData

/// Packaged-food lookup backed by the public Open Food Facts API: search by name, or scan / type a
/// barcode. Every product the user opens is saved with SwiftData (see `SavedProductRecord`), which
/// powers the Recent and Favorites lists and lets saved products open offline.
///
/// Used both as its own tab and as a sheet from the diary's "Add Food" (then `presetMealType` is set).
struct FoodLookupView: View {
    var presetMealType: MealType?
    var dateKey: String?
    var isSheet = false

    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SavedProductRecord.lastViewedAt, order: .reverse) private var savedProducts: [SavedProductRecord]

    private enum Phase: Equatable {
        case idle, loading, loaded, failed(OpenFoodFactsAPI.OFFError)
    }

    @State private var query = ""
    @State private var results: [OFFProduct] = []
    @State private var phase: Phase = .idle
    @State private var path: [OFFProduct] = []
    @State private var showScanner = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeError: OpenFoodFactsAPI.OFFError?
    @State private var offlineNotice = false

    private var favorites: [SavedProductRecord] { savedProducts.filter(\.isFavorite) }
    private var isSearching: Bool { query.trimmingCharacters(in: .whitespaces).count >= 2 }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isSearching {
                        searchResults
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        scanCard
                        if !favorites.isEmpty { favoritesSection }
                        recentSection
                        Text(localization.t("lookup.poweredBy"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .animation(.snappy, value: isSearching)
                .animation(.snappy, value: phase)
            }
            .background(Theme.screenBackground)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(localization.t("lookup.title"))
            .searchable(text: $query, prompt: localization.t("lookup.searchPrompt"))
            .task(id: query) { await runSearch() }
            .navigationDestination(for: OFFProduct.self) { product in
                ProductDetailView(
                    product: product,
                    presetMealType: presetMealType,
                    dateKey: dateKey,
                    onLogged: isSheet ? { dismiss() } : nil
                )
            }
            .toolbar {
                if isSheet {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localization.t("common.cancel")) { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showScanner = true } label: { Image(systemName: "barcode.viewfinder") }
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerSheet { code in Task { await lookUp(barcode: code) } }
            }
            .overlay {
                if isLookingUpBarcode {
                    ProgressView(localization.t("lookup.searching"))
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if offlineNotice {
                    Label(localization.t("lookup.cachedOffline"), systemImage: "wifi.slash")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: isLookingUpBarcode)
            .animation(.spring(duration: 0.35), value: offlineNotice)
            .alert(
                localization.t("lookup.title"),
                isPresented: Binding(get: { barcodeError != nil }, set: { if !$0 { barcodeError = nil } }),
                presenting: barcodeError
            ) { _ in
                Button(localization.t("common.ok"), role: .cancel) {}
            } message: { error in
                Text(localization.t(error.messageKey))
            }
            .sensoryFeedback(.error, trigger: barcodeError) { _, new in new != nil }
        }
    }

    // MARK: - Sections

    private var scanCard: some View {
        Button { showScanner = true } label: {
            HStack(spacing: 16) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolEffect(.pulse, options: .repeating)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.t("lookup.scan")).font(.title3.bold())
                    Text(localization.t("lookup.scanHint")).font(.footnote).opacity(0.9)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.headline).opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(
                LinearGradient(colors: [Theme.calorie, .pink.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: Theme.calorie.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.t("lookup.favorites"), systemImage: "heart.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favorites) { record in
                        NavigationLink(value: record.asProduct) {
                            FavoriteCard(record: record)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.vertical, 4)
                .animation(.spring, value: favorites.map(\.barcode))
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.t("lookup.recent"), systemImage: "clock.arrow.circlepath")
            if savedProducts.isEmpty {
                ContentUnavailableView(
                    localization.t("lookup.emptyTitle"),
                    systemImage: "shippingbox",
                    description: Text(localization.t("lookup.emptyHint"))
                )
                .cardStyle()
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(savedProducts.prefix(20)) { record in
                        NavigationLink(value: record.asProduct) {
                            ProductRow(product: record.asProduct, isFavorite: record.isFavorite)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        switch phase {
        case .idle, .loading:
            VStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    ProductRow(product: .placeholder, isFavorite: false)
                        .redacted(reason: .placeholder)
                        .shimmering()
                }
            }
        case .failed(let error):
            ContentUnavailableView {
                Label(localization.t(error.messageKey), systemImage: error == .offline ? "wifi.slash" : "exclamationmark.triangle")
            } actions: {
                Button(localization.t("common.retry")) { Task { await runSearch(debounce: false) } }
                    .buttonStyle(.borderedProminent)
            }
            .cardStyle()
        case .loaded where results.isEmpty:
            ContentUnavailableView(
                localization.t("lookup.noResults"),
                systemImage: "magnifyingglass",
                description: Text(localization.t("lookup.noResultsHint"))
            )
            .cardStyle()
        case .loaded:
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(localization.t("lookup.results") + " · \(results.count)", systemImage: "list.bullet")
                LazyVStack(spacing: 10) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, product in
                        NavigationLink(value: product) {
                            ProductRow(product: product, isFavorite: savedProducts.first { $0.barcode == product.code }?.isFavorite ?? false)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .staggeredAppear(index: index)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    // MARK: - Actions

    /// Debounced so typing "coca cola" fires one request instead of nine — OFF rate-limits search.
    /// `.task(id: query)` cancels the previous run whenever the text changes.
    private func runSearch(debounce: Bool = true) async {
        guard isSearching else {
            results = []
            phase = .idle
            return
        }
        phase = .loading
        if debounce {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
        }
        do {
            let found = try await OpenFoodFactsAPI.search(query)
            guard !Task.isCancelled else { return }
            results = found
            phase = .loaded
        } catch is CancellationError {
            return
        } catch let error as OpenFoodFactsAPI.OFFError {
            phase = .failed(error)
        } catch {
            phase = .failed(.server(status: 0))
        }
    }

    /// Network first so the saved copy stays fresh; if offline, fall back to the SwiftData copy.
    private func lookUp(barcode: String) async {
        isLookingUpBarcode = true
        defer { isLookingUpBarcode = false }
        do {
            let product = try await OpenFoodFactsAPI.product(barcode: barcode)
            path.append(product)
        } catch let error as OpenFoodFactsAPI.OFFError {
            if error == .offline || error.isServerError, let cached = savedProducts.first(where: { $0.barcode == barcode }) {
                path.append(cached.asProduct)
                offlineNotice = true
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    offlineNotice = false
                }
            } else {
                barcodeError = error
            }
        } catch {
            barcodeError = .server(status: 0)
        }
    }
}

private extension OpenFoodFactsAPI.OFFError {
    var isServerError: Bool {
        if case .server = self { return true }
        return false
    }
}

// MARK: - Rows & cards

struct ProductRow: View {
    let product: OFFProduct
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(url: product.imageURL, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let brand = product.brand {
                    Text(brand).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int((product.nutriments.kcal ?? 0).rounded()))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.calorie)
                Text("kcal/100g").font(.caption2).foregroundStyle(.secondary)
            }
            if isFavorite {
                Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink)
            }
        }
        .foregroundStyle(.primary)
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }
}

private struct FavoriteCard: View {
    let record: SavedProductRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProductThumbnail(url: record.imageURLString.flatMap(URL.init(string:)), size: 96)
            Text(record.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Text("\(Int(record.kcalPer100g.rounded())) kcal")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.calorie)
        }
        .foregroundStyle(.primary)
        .frame(width: 96)
        .padding(10)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }
}

struct ProductThumbnail: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill().transition(.opacity)
            default:
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(Theme.calorie.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .background(Theme.calorie.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

extension OFFProduct {
    /// Fake row used for the loading skeleton.
    static let placeholder = OFFProduct(
        code: "0", name: "Loading product name", brand: "Brand", imageURL: nil,
        servingSize: nil, servingGrams: nil, nutriments: OFFNutriments(kcal: 100)
    )
}
