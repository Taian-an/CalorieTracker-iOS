import XCTest
@testable import CalorieTracker

/// Open Food Facts is crowd-sourced, so the same field shows up in different shapes. These cover
/// each inconsistency `OFFProduct` / `OFFNutriments` are written to tolerate.
final class OpenFoodFactsDecodingTests: XCTestCase {
    func testDecodeProductEndpoint() throws {
        let json = """
        {"code":"5449000000996","status":1,"product":{"code":"5449000000996","product_name":"Coca-Cola","brands":"COCA-COLA SERVICES SA/NV, Coca-Cola","serving_size":"1 portion (330 ml)","serving_quantity":330,"nutriments":{"energy-kcal_100g":42,"proteins_100g":0,"carbohydrates_100g":10.6,"fat_100g":0,"sugars_100g":10.6,"sodium_100g":0}}}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: json)
        let product = try XCTUnwrap(response.product)
        XCTAssertEqual(response.status, 1)
        XCTAssertEqual(product.name, "Coca-Cola")
        XCTAssertEqual(product.brand, "COCA-COLA SERVICES SA/NV") // first of a comma-separated list
        XCTAssertEqual(product.servingGrams, 330)
        XCTAssertEqual(product.nutriments.kcal, 42)
        XCTAssertEqual(product.nutriments.carbs, 10.6)
    }

    func testNotFoundHasNoProduct() throws {
        let json = #"{"code":"4710088410619","status":0,"status_verbose":"product not found"}"#.data(using: .utf8)!
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: json)
        XCTAssertEqual(response.status, 0)
        XCTAssertNil(response.product)
    }

    /// search.openfoodfacts.org returns `brands` as an array, and some products only have kJ.
    func testSearchHitWithBrandArrayAndKilojoulesOnly() throws {
        let json = """
        {"hits":[{"code":"2000000046692","brands":["Oreo"],"product_name":"oreo","nutriments":{"energy-kj_100g":1955,"proteins_100g":5.1,"carbohydrates_100g":69.5,"fat_100g":18}}]}
        """.data(using: .utf8)!
        let hit = try XCTUnwrap(JSONDecoder().decode(OFFSearchResponse.self, from: json).hits.first)
        XCTAssertEqual(hit.brand, "Oreo")
        XCTAssertEqual(try XCTUnwrap(hit.nutriments.kcal), 1955 / 4.184, accuracy: 0.01)
    }

    /// Numbers-as-strings, missing name, missing nutriments — must still decode, not throw.
    func testMessyProductStillDecodes() throws {
        let json = #"{"code":"123","serving_quantity":"25,5","nutriments":{"energy-kcal_100g":"480","fat_100g":null}}"#.data(using: .utf8)!
        let product = try JSONDecoder().decode(OFFProduct.self, from: json)
        XCTAssertEqual(product.name, "#123")
        XCTAssertNil(product.brand)
        XCTAssertEqual(product.servingGrams, 25.5)
        XCTAssertEqual(product.nutriments.kcal, 480)
        XCTAssertNil(product.nutriments.fat)
        XCTAssertTrue(product.nutriments.hasEnergy)
    }

    func testProductWithoutEnergyIsNotLoggable() throws {
        let json = #"{"code":"1","product_name":"Water"}"#.data(using: .utf8)!
        let product = try JSONDecoder().decode(OFFProduct.self, from: json)
        XCTAssertFalse(product.nutriments.hasEnergy)
    }

    func testInvalidBarcodeIsRejectedBeforeNetwork() async {
        do {
            _ = try await OpenFoodFactsAPI.product(barcode: "123")
            XCTFail("expected invalidBarcode")
        } catch {
            XCTAssertEqual(error as? OpenFoodFactsAPI.OFFError, .invalidBarcode)
        }
    }
}
