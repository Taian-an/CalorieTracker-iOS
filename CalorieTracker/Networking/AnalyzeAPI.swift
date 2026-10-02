import Foundation
import UIKit

enum AnalyzeAPI {
    /// The server shrinks photos to 1024px before sending them to the AI anyway, so uploading the
    /// full 12MP capture only costs seconds of upload time for no accuracy gain.
    private static let maxUploadEdge: CGFloat = 1280
    private static let pollInterval: Duration = .milliseconds(500)
    private static let maxPollDuration: Duration = .seconds(30)

    /// `language` ("en" | "zh") picks the language of the AI's food name and item breakdown.
    static func analyze(image: UIImage, description: String?, language: String) async throws -> AnalyzeResultDTO {
        guard let imageData = downscaled(image).jpegData(compressionQuality: 0.8) else {
            throw APIError.encodingFailed
        }
        var fields: [String: String] = ["lang": language]
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["description"] = description
        }
        let response: AnalyzeStatusDTO = try await APIClient.shared.upload(
            "/analyze",
            imageData: imageData,
            imageFieldName: "images", // must match multer's upload.array('images', 5) on the server
            fields: fields,
            auth: .required // AI scans require an account since 2026-10 (they cost money per call)
        )
        if let result = response.result { return result }
        guard let analysisId = response.analysisId else {
            throw APIError.server(status: 502, message: response.error ?? "Analysis failed")
        }
        return try await poll(analysisId)
    }

    private static func poll(_ analysisId: String) async throws -> AnalyzeResultDTO {
        let clock = ContinuousClock()
        let deadline = clock.now + maxPollDuration
        while clock.now < deadline {
            try await Task.sleep(for: pollInterval)
            let status: AnalyzeStatusDTO = try await APIClient.shared.request("/analyses/\(analysisId)", method: .get, auth: .optional)
            if let result = status.result { return result }
            if status.status == "failed" {
                throw APIError.server(status: 502, message: status.error ?? "Analysis failed")
            }
        }
        throw APIError.server(status: 504, message: "Analysis timed out")
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let longEdge = max(image.size.width, image.size.height)
        guard longEdge > maxUploadEdge else { return image }
        let scale = maxUploadEdge / longEdge
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // exact pixel size, not the screen's 3x
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func recentAnalyses() async throws -> [AnalysisHistoryItemDTO] {
        try await APIClient.shared.request("/analyses", method: .get, auth: .required)
    }
}

enum FoodsAPI {
    static func search(_ query: String) async throws -> [FoodSearchResultDTO] {
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { return [] }
        return try await APIClient.shared.request("/foods/search", method: .get, query: ["q": query], auth: .none)
    }
}

enum FeedbackAPI {
    static func submit(message: String, email: String?) async throws {
        let body = FeedbackRequest(message: message, email: email)
        try await APIClient.shared.requestVoid("/feedback", method: .post, body: body, auth: .optional)
    }
}
