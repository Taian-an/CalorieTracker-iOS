import Foundation

struct CoachMessageDTO: Codable, Equatable {
    /// "user" or "model", as expected by the server.
    var role: String
    var text: String
}

private struct CoachChatRequest: Encodable {
    var messages: [CoachMessageDTO]
    var lang: String
}

private struct CoachChatResponse: Decodable {
    var reply: String
}

enum CoachAPI {
    /// Sends the whole conversation each time (the server keeps no chat history) and returns the reply.
    static func send(messages: [CoachMessageDTO], language: String) async throws -> String {
        let response: CoachChatResponse = try await APIClient.shared.request(
            "/coach/chat",
            method: .post,
            body: CoachChatRequest(messages: messages, lang: language),
            auth: .required
        )
        return response.reply
    }
}
