import Foundation

// Open Food Facts (https://world.openfoodfacts.org) is a free, public, crowd-sourced database of
// packaged foods — no API key. Because anyone can edit it, the JSON is inconsistent between
// products and between its two endpoints, so decoding here is deliberately defensive:
//   - `brands` is a comma-separated String on /api/v2/product but a [String] on search.openfoodfacts.org
//   - numbers sometimes arrive as strings ("330") and `serving_quantity` may be missing entirely
//   - some products only report energy in kJ (`energy-kj_100g`), never kcal
//   - any nutrient can be absent

/// GET https://world.openfoodfacts.org/api/v2/product/{barcode}.json
struct OFFProductResponse: Decodable {
    /// 1 = found, 0 = not found / invalid barcode (the HTTP status is 404 for "not found").
    let status: Int
    let product: OFFProduct?
}

/// GET https://search.openfoodfacts.org/search?q=…
struct OFFSearchResponse: Decodable {
    let hits: [OFFProduct]
}

struct OFFProduct: Decodable, Identifiable, Hashable {
    let code: String
    let name: String
    let brand: String?
    let imageURL: URL?
    let servingSize: String?
    let servingGrams: Double?
    let nutriments: OFFNutriments

    var id: String { code }

    private enum CodingKeys: String, CodingKey {
        case code, brands, nutriments
        case productName = "product_name"
        case imageURL = "image_front_small_url"
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
    }

    init(code: String, name: String, brand: String?, imageURL: URL?, servingSize: String?, servingGrams: Double?, nutriments: OFFNutriments) {
        self.code = code
        self.name = name
        self.brand = brand
        self.imageURL = imageURL
        self.servingSize = servingSize
        self.servingGrams = servingGrams
        self.nutriments = nutriments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)

        let rawName = (try? c.decodeIfPresent(String.self, forKey: .productName)) ?? nil
        name = rawName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "#\(code)"

        if let list = try? c.decodeIfPresent([String].self, forKey: .brands) {
            brand = list.first?.nonEmpty
        } else if let text = try? c.decodeIfPresent(String.self, forKey: .brands) {
            brand = text.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) }?.nonEmpty
        } else {
            brand = nil
        }

        imageURL = (try? c.decodeIfPresent(URL.self, forKey: .imageURL)) ?? nil
        servingSize = ((try? c.decodeIfPresent(String.self, forKey: .servingSize)) ?? nil)?.nonEmpty
        servingGrams = (try? c.decodeIfPresent(FlexibleDouble.self, forKey: .servingQuantity))??.value
            .flatMap { $0 > 0 ? $0 : nil }
        nutriments = (try? c.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)) ?? OFFNutriments()
    }
}

/// Per-100 g values. Missing nutrients decode as nil rather than failing the whole product.
struct OFFNutriments: Decodable, Hashable {
    var kcal: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var sugar: Double?
    var fiber: Double?
    /// grams per 100 g (OFF reports sodium in g, not mg)
    var sodium: Double?

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(kcal: Double? = nil, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil,
         sugar: Double? = nil, fiber: Double? = nil, sodium: Double? = nil) {
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.sugar = sugar
        self.fiber = fiber
        self.sodium = sodium
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        func value(_ key: String) -> Double? {
            (try? c.decodeIfPresent(FlexibleDouble.self, forKey: Key(stringValue: key)))??.value
        }
        // 1 kcal = 4.184 kJ — used only when the product has no kcal figure at all
        kcal = value("energy-kcal_100g") ?? value("energy-kj_100g").map { $0 / 4.184 }
        protein = value("proteins_100g")
        carbs = value("carbohydrates_100g")
        fat = value("fat_100g")
        sugar = value("sugars_100g")
        fiber = value("fiber_100g")
        sodium = value("sodium_100g")
    }

    /// A product with no energy value can't be logged meaningfully.
    var hasEnergy: Bool { (kcal ?? 0) > 0 }
}

/// Decodes a JSON number, or a string containing a number ("330", "12.5").
struct FlexibleDouble: Decodable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let number = try? c.decode(Double.self) {
            value = number.isFinite ? number : nil
        } else if let text = try? c.decode(String.self) {
            value = Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        } else {
            value = nil
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
