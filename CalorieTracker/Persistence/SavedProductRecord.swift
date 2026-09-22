import Foundation
import SwiftData

/// An Open Food Facts product the user has opened, kept on device with SwiftData.
///
/// Doubles as two features: the "Recent" / "Favorites" lists on the lookup screen, and an offline
/// cache — scanning a barcode that's already saved shows it instantly, even with no network.
@Model
final class SavedProductRecord {
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String?
    var imageURLString: String?
    var servingSize: String?
    var servingGrams: Double?
    var kcalPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarPer100g: Double?
    var fiberPer100g: Double?
    var sodiumPer100g: Double?
    var isFavorite: Bool = false
    var lastViewedAt: Date

    init(_ product: OFFProduct) {
        barcode = product.code
        name = product.name
        kcalPer100g = product.nutriments.kcal ?? 0
        proteinPer100g = product.nutriments.protein ?? 0
        carbsPer100g = product.nutriments.carbs ?? 0
        fatPer100g = product.nutriments.fat ?? 0
        lastViewedAt = Date()
        update(from: product)
    }

    /// Refreshes the cached copy with the latest data from the API, keeping `isFavorite`.
    func update(from product: OFFProduct) {
        name = product.name
        brand = product.brand
        imageURLString = product.imageURL?.absoluteString
        servingSize = product.servingSize
        servingGrams = product.servingGrams
        kcalPer100g = product.nutriments.kcal ?? 0
        proteinPer100g = product.nutriments.protein ?? 0
        carbsPer100g = product.nutriments.carbs ?? 0
        fatPer100g = product.nutriments.fat ?? 0
        sugarPer100g = product.nutriments.sugar
        fiberPer100g = product.nutriments.fiber
        sodiumPer100g = product.nutriments.sodium
        lastViewedAt = Date()
    }

    var asProduct: OFFProduct {
        OFFProduct(
            code: barcode,
            name: name,
            brand: brand,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            servingSize: servingSize,
            servingGrams: servingGrams,
            nutriments: OFFNutriments(
                kcal: kcalPer100g, protein: proteinPer100g, carbs: carbsPer100g, fat: fatPer100g,
                sugar: sugarPer100g, fiber: fiberPer100g, sodium: sodiumPer100g
            )
        )
    }
}
