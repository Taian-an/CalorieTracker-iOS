import XCTest
@testable import CalorieTracker

final class DTODecodingTests: XCTestCase {
    func testDecodeAuthResponse() throws {
        let json = """
        {"token":"abc.def.ghi","profile":{"email":"a@b.com","username":"alex","gender":"male","age":30,"height":175,"weight":70,"activity":"sedentary","goal":"cut","bmr":1600,"tdee":1920,"target":1520}}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(AuthResponseDTO.self, from: json)
        XCTAssertEqual(response.token, "abc.def.ghi")
        XCTAssertEqual(response.profile.email, "a@b.com")
        XCTAssertEqual(response.profile.gender, .male)
        XCTAssertEqual(response.profile.goal, .cut)
        XCTAssertTrue(response.profile.isOnboarded)
    }

    func testDecodeLogsResponse() throws {
        let json = """
        {"2026-09-10":{"weight":70,"target":2000,"meals":[{"name":"Pad Thai","energy":450,"protein":15,"carbs":60,"fat":12,"mealType":"lunch","time":1757490000000,"grams":300}]}}
        """.data(using: .utf8)!
        let logs = try JSONDecoder().decode(LogsResponse.self, from: json)
        let day = try XCTUnwrap(logs["2026-09-10"])
        XCTAssertEqual(day.weight, 70)
        XCTAssertEqual(day.meals.first?.name, "Pad Thai")
        XCTAssertEqual(day.meals.first?.mealType, .lunch)
    }

    func testDecodeAnalyzeResult() throws {
        let json = """
        {"name":"Grilled Chicken","confidence":87,"energy":320,"protein":40.5,"carbs":2.1,"fat":12.3,"grams":180}
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(AnalyzeResultDTO.self, from: json)
        XCTAssertEqual(result.name, "Grilled Chicken")
        XCTAssertEqual(result.grams, 180)
    }

    /// POST /analyze answers inline with the result once the server-side wait finishes.
    func testDecodeAnalyzeStatusDoneWithItems() throws {
        let json = """
        {"analysisId":"6ab2","status":"done","name":"滷肉飯","energy":617,"protein":21.5,"carbs":62.8,"fat":31.2,"grams":385,"confidence":0.85,"items":[{"name":"白飯","grams":180,"calories":234}]}
        """.data(using: .utf8)!
        let status = try JSONDecoder().decode(AnalyzeStatusDTO.self, from: json)
        let result = try XCTUnwrap(status.result)
        XCTAssertEqual(result.energy, 617)
        XCTAssertEqual(result.items, [AnalyzeItemDTO(name: "白飯", grams: 180, calories: 234)])
    }

    /// When the queue is backed up the server answers 202 with only an id, and the client polls.
    func testDecodeAnalyzeStatusPending() throws {
        let json = #"{"analysisId":"6ab2","status":"pending"}"#.data(using: .utf8)!
        let status = try JSONDecoder().decode(AnalyzeStatusDTO.self, from: json)
        XCTAssertNil(status.result)
        XCTAssertEqual(status.analysisId, "6ab2")
    }

    /// Regression test: the currently-deployed production server predates the `grams` field on
    /// POST /analyze (confirmed via a live curl against it), so decoding must not fail when it's
    /// absent — it should default to 100, matching the server's own `estimatedGrams ?? 100`.
    func testDecodeAnalyzeResultWithoutGrams() throws {
        let json = """
        {"name":"Turkey, neck","confidence":96,"energy":161,"protein":22.29,"carbs":0,"fat":7.3}
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(AnalyzeResultDTO.self, from: json)
        XCTAssertEqual(result.name, "Turkey, neck")
        XCTAssertEqual(result.grams, 100)
    }

    func testEncodeProfilePatchOmitsNilFields() throws {
        var patch = ProfileDTO()
        patch.weight = 68
        let data = try JSONEncoder().encode(patch)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object.count, 1)
        XCTAssertEqual(object["weight"] as? Double, 68)
    }

    func testDateKeyIsLocalNotUTC() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 23
        components.minute = 30
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(DateKey.string(for: date), "2026-01-15")
    }
}
