import Foundation

/// Client for the public Open Food Facts REST API — called straight from the app with
/// URLSession + async/await (unlike `APIClient`, which talks to our own backend).
///
/// OFF asks every client to send a descriptive User-Agent, and rate-limits search to roughly
/// 10 requests/minute per IP, so searches are debounced in the UI and 429 is surfaced as its own error.
enum OpenFoodFactsAPI {
    enum OFFError: LocalizedError, Equatable {
        case invalidBarcode
        case notFound
        case noNutritionData
        case rateLimited
        case offline
        case server(status: Int)
        case decoding

        /// Localization key in `Strings.table`; the view layer turns this into the user's language.
        var messageKey: String {
            switch self {
            case .invalidBarcode: return "lookup.error.invalidBarcode"
            case .notFound: return "lookup.error.notFound"
            case .noNutritionData: return "lookup.error.noNutrition"
            case .rateLimited: return "lookup.error.rateLimited"
            case .offline: return "lookup.error.offline"
            case .server: return "lookup.error.server"
            case .decoding: return "lookup.error.decoding"
            }
        }

        var errorDescription: String? { messageKey }
    }

    private static let fields = "code,product_name,brands,nutriments,serving_size,serving_quantity,image_front_small_url"

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.httpAdditionalHeaders = ["User-Agent": "CalorieTracker-iOS/1.0 (student project)"]
        config.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: config)
    }()

    /// Looks up one packaged product by its EAN-13 / UPC-A / EAN-8 barcode.
    static func product(barcode: String) async throws -> OFFProduct {
        let digits = barcode.filter(\.isNumber)
        guard [8, 12, 13, 14].contains(digits.count) else { throw OFFError.invalidBarcode }

        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json")!
        components.queryItems = [URLQueryItem(name: "fields", value: fields)]

        // OFF answers 404 *with a JSON body* ({"status":0}) for unknown barcodes, so 404 is allowed through.
        let data = try await get(components.url!, allowing: [200, 404])
        let response = try decode(OFFProductResponse.self, from: data)
        guard response.status == 1, let product = response.product else { throw OFFError.notFound }
        guard product.nutriments.hasEnergy else { throw OFFError.noNutritionData }
        return product
    }

    /// Full-text product search. Results without an energy value are dropped since they can't be logged.
    static func search(_ query: String) async throws -> [OFFProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        var components = URLComponents(string: "https://search.openfoodfacts.org/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "fields", value: fields),
        ]
        let data = try await get(components.url!, allowing: [200])
        return try decode(OFFSearchResponse.self, from: data).hits.filter(\.nutriments.hasEnergy)
    }

    // MARK: - Plumbing

    private static func get(_ url: URL, allowing okStatuses: Set<Int>) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError() // a newer search replaced this one — not a user-facing error
        } catch {
            throw OFFError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw OFFError.server(status: 0) }
        if http.statusCode == 429 { throw OFFError.rateLimited }
        guard okStatuses.contains(http.statusCode) else { throw OFFError.server(status: http.statusCode) }
        return data
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OFFError.decoding
        }
    }
}
