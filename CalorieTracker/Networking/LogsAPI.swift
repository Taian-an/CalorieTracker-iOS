import Foundation

enum LogsAPI {
    static func fetchLogs(from: String? = nil, to: String? = nil) async throws -> LogsResponse {
        var query: [String: String] = [:]
        if let from { query["from"] = from }
        if let to { query["to"] = to }
        return try await APIClient.shared.request("/logs", method: .get, query: query, auth: .required)
    }

    /// Full-day overwrite, matches server.js's PUT /logs/:date semantics.
    static func putLog(date: String, log: DayLogDTO) async throws {
        try await APIClient.shared.requestVoid("/logs/\(date)", method: .put, body: log, auth: .required)
    }
}
