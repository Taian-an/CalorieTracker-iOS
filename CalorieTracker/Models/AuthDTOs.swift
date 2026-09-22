import Foundation

struct AuthResponseDTO: Codable {
    let token: String
    let profile: ProfileDTO
}

struct RegisterRequest: Encodable {
    var email: String
    var username: String
    var password: String
    var profile: [String: String]?
}

struct LoginRequest: Encodable {
    var email: String
    var password: String
}

struct GoogleLoginRequest: Encodable {
    var idToken: String
}

struct ErrorResponse: Decodable {
    let error: String
}
