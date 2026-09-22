import Foundation

/// Response of POST /analyze.
///
/// `grams` is declared optional and defaulted to 100 (matching the server's own `estimatedGrams
/// ?? 100` fallback in server.js) because the currently-deployed production server predates the
/// grams field being added to this response — decoding must tolerate it being absent rather than
/// failing the whole request.
struct AnalyzeResultDTO: Codable, Equatable {
    var name: String
    var confidence: Double
    var energy: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var grams: Double
    /// AI's per-component breakdown (rice 180g / 234 kcal, …). Absent on older servers.
    var items: [AnalyzeItemDTO] = []

    enum CodingKeys: String, CodingKey {
        case name, confidence, energy, protein, carbs, fat, grams, items
    }

    init(name: String, confidence: Double, energy: Double, protein: Double, carbs: Double, fat: Double, grams: Double, items: [AnalyzeItemDTO] = []) {
        self.name = name
        self.confidence = confidence
        self.energy = energy
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.grams = grams
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        confidence = try container.decode(Double.self, forKey: .confidence)
        energy = try container.decode(Double.self, forKey: .energy)
        protein = try container.decode(Double.self, forKey: .protein)
        carbs = try container.decode(Double.self, forKey: .carbs)
        fat = try container.decode(Double.self, forKey: .fat)
        grams = try container.decodeIfPresent(Double.self, forKey: .grams) ?? 100
        items = try container.decodeIfPresent([AnalyzeItemDTO].self, forKey: .items) ?? []
    }
}

struct AnalyzeItemDTO: Codable, Equatable {
    var name: String
    var grams: Double
    var calories: Double
}

/// Envelope shared by POST /analyze and GET /analyses/:id. The server waits for the result inside
/// POST /analyze and answers `status: "done"` with the result fields inline; only when its queue is
/// backed up does it answer `status: "pending"` + `analysisId`, and the client polls until done/failed.
struct AnalyzeStatusDTO: Decodable {
    var status: String
    var analysisId: String?
    var error: String?
    var result: AnalyzeResultDTO?

    private enum CodingKeys: String, CodingKey { case status, analysisId, error }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "done"
        analysisId = try container.decodeIfPresent(String.self, forKey: .analysisId)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        result = status == "done" ? try AnalyzeResultDTO(from: decoder) : nil
    }
}

/// One item of GET /foods/search.
struct FoodSearchResultDTO: Codable, Equatable, Identifiable {
    var name: String
    var energy: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var source: String

    var id: String { name }
}

/// One item of GET /analyses.
struct AnalysisHistoryItemDTO: Codable, Equatable, Identifiable {
    var matchedName: String
    var source: String
    var result: AnalyzeResultDTO
    var createdAt: String

    var id: String { createdAt + matchedName }
}

struct FeedbackRequest: Encodable {
    var message: String
    var email: String?
}
