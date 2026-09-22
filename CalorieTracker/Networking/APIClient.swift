import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case encodingFailed
    case decodingFailed(Error)
    case server(status: Int, message: String)
    case unauthorized
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL."
        case .encodingFailed: return "Failed to encode request body."
        case .decodingFailed: return "Failed to decode server response."
        case .server(_, let message): return message
        case .unauthorized: return "Please sign in again."
        case .transport(let error): return error.localizedDescription
        }
    }
}

/// Whether a request requires a JWT to be attached.
enum AuthRequirement {
    case none
    case optional
    case required
}

/// Thin async/await wrapper around URLSession, matching server.js's routes 1:1.
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.networkTimeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - JSON requests

    func request<Response: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        query: [String: String]? = nil,
        body: Encodable? = nil,
        auth: AuthRequirement = .none
    ) async throws -> Response {
        let data = try await requestData(path, method: method, query: query, body: body, auth: auth)
        return try decode(data)
    }

    /// For endpoints like PUT /logs/:date that only return `{ok:true}` and we don't care about the payload.
    @discardableResult
    func requestVoid(
        _ path: String,
        method: HTTPMethod = .get,
        query: [String: String]? = nil,
        body: Encodable? = nil,
        auth: AuthRequirement = .none
    ) async throws -> Data {
        try await requestData(path, method: method, query: query, body: body, auth: auth)
    }

    private func requestData(
        _ path: String,
        method: HTTPMethod,
        query: [String: String]?,
        body: Encodable?,
        auth: AuthRequirement
    ) async throws -> Data {
        var urlRequest = try makeRequest(path: path, method: method, query: query, auth: auth)

        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                urlRequest.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            } catch {
                throw APIError.encodingFailed
            }
        }

        return try await perform(urlRequest)
    }

    // MARK: - Multipart upload (POST /analyze)

    func upload<Response: Decodable>(
        _ path: String,
        imageData: Data,
        imageFieldName: String = "image",
        fileName: String = "photo.jpg",
        mimeType: String = "image/jpeg",
        fields: [String: String] = [:],
        auth: AuthRequirement = .optional
    ) async throws -> Response {
        var urlRequest = try makeRequest(path: path, method: .post, query: nil, auth: auth)

        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(imageFieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        urlRequest.httpBody = body

        let data = try await perform(urlRequest)
        return try decode(data)
    }

    // MARK: - Shared plumbing

    private func makeRequest(
        path: String,
        method: HTTPMethod,
        query: [String: String]?,
        auth: AuthRequirement
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if let query, !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue

        let token = KeychainStore.loadToken()
        switch auth {
        case .none:
            break
        case .optional:
            if let token { urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        case .required:
            guard let token else { throw APIError.unauthorized }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return urlRequest
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(status: 0, message: "No HTTP response.")
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.server(status: http.statusCode, message: message)
        }

        return data
    }

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}

/// Type-erasing box so `request(body: Encodable?)` can accept any Encodable value.
private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeClosure = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
