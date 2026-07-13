import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .httpStatus(code, message):
            if let message, !message.isEmpty {
                return "Request failed (\(code)): \(message)"
            }
            return "Request failed with status code \(code)."
        case let .decodingFailed(message):
            return message
        }
    }
}

protocol TokenProviding: AnyObject {
    func idToken(forceRefresh: Bool) async throws -> String?
}

final class APIClient {
    let baseURL: URL
    let session: URLSession
    weak var tokenProvider: TokenProviding?
    let decoder: JSONDecoder

    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        session: URLSession = .shared,
        tokenProvider: TokenProviding? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = JSONDecoder.apiDecoder()
    }

    func setTokenProvider(_ tokenProvider: TokenProviding?) {
        self.tokenProvider = tokenProvider
    }

    func get<T: Decodable>(_ endpoint: APIEndpoint, authenticated: Bool = false) async throws -> T {
        try await request(endpoint, body: Optional<String>.none, authenticated: authenticated)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ endpoint: APIEndpoint,
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        try await request(endpoint, body: body, authenticated: authenticated)
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ endpoint: APIEndpoint,
        body: Body?,
        authenticated: Bool
    ) async throws -> Response {
        var request = URLRequest(url: endpoint.url(baseURL: baseURL))
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        if authenticated, let token = try await tokenProvider?.idToken(forceRefresh: false) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = Self.apiErrorDetail(from: data) ?? String(data: data, encoding: .utf8)
            throw APIError.httpStatus(httpResponse.statusCode, message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed(Self.decodingErrorMessage(error))
        }
    }

    static func apiErrorDetail(from data: Data) -> String? {
        struct ErrorBody: Decodable {
            let detail: String
        }
        return (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail
    }

    static func decodingErrorMessage(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case let .typeMismatch(type, context):
            return "Unexpected value for \(context.codingPath.map(\.stringValue).joined(separator: ".")): expected \(type)."
        case let .valueNotFound(type, context):
            return "Missing value for \(context.codingPath.map(\.stringValue).joined(separator: ".")): expected \(type)."
        case let .keyNotFound(key, context):
            return "Missing field \(key.stringValue) in \(context.codingPath.map(\.stringValue).joined(separator: "."))."
        case let .dataCorrupted(context):
            return context.debugDescription
        @unknown default:
            return decodingError.localizedDescription
        }
    }
}
