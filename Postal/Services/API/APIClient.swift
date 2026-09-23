import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    /// `body` is the raw response for structured detail (e.g. 402 stamp shortage).
    case httpStatus(Int, String?, body: Data? = nil)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .httpStatus(code, message, _):
            if let message, !message.isEmpty {
                return "Request failed (\(code)): \(message)"
            }
            return "Request failed with status code \(code)."
        case let .decodingFailed(message):
            return message
        }
    }

    var httpStatusCode: Int? {
        guard case let .httpStatus(code, _, _) = self else { return nil }
        return code
    }

    /// Parsed when the server returns a 402 with an object `detail`.
    var insufficientStampsDetail: InsufficientStampsDetail? {
        guard case let .httpStatus(402, _, body) = self, let body else { return nil }
        struct Body: Decodable {
            let detail: InsufficientStampsDetail
        }
        return try? JSONDecoder().decode(Body.self, from: body).detail
    }

    /// Parsed when a send is refused because the two users are blocked. A 403 with
    /// a plain string `detail` (origin ownership, Plus-only estimates) decodes to nil.
    var sendBlockedDetail: SendBlockedDetail? {
        guard case let .httpStatus(403, _, body) = self, let body else { return nil }
        struct Body: Decodable {
            let detail: SendBlockedDetail
        }
        return try? JSONDecoder().decode(Body.self, from: body).detail
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

    /// POST with no JSON body (e.g. stamp allowance claim).
    func postEmpty<Response: Decodable>(
        _ endpoint: APIEndpoint,
        authenticated: Bool = true
    ) async throws -> Response {
        try await request(endpoint, body: Optional<String>.none, authenticated: authenticated)
    }

    func put<Body: Encodable, Response: Decodable>(
        _ endpoint: APIEndpoint,
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        try await request(endpoint, body: body, authenticated: authenticated)
    }

    func delete<Body: Encodable, Response: Decodable>(
        _ endpoint: APIEndpoint,
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        try await request(endpoint, body: body, authenticated: authenticated)
    }

    /// Performs a DELETE that returns no body (e.g. HTTP 204).
    func delete(_ endpoint: APIEndpoint, authenticated: Bool = true) async throws {
        try await requestNoContent(endpoint, authenticated: authenticated)
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ endpoint: APIEndpoint,
        body: Body?,
        authenticated: Bool
    ) async throws -> Response {
        let data = try await perform(endpoint, body: body, authenticated: authenticated)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed(Self.decodingErrorMessage(error))
        }
    }

    private func requestNoContent(_ endpoint: APIEndpoint, authenticated: Bool) async throws {
        _ = try await perform(endpoint, body: Optional<String>.none, authenticated: authenticated)
    }

    private func perform<Body: Encodable>(
        _ endpoint: APIEndpoint,
        body: Body?,
        authenticated: Bool
    ) async throws -> Data {
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
            throw APIError.httpStatus(httpResponse.statusCode, message, body: data)
        }

        return data
    }

    static func apiErrorDetail(from data: Data) -> String? {
        struct StringDetailBody: Decodable {
            let detail: String
        }
        if let body = try? JSONDecoder().decode(StringDetailBody.self, from: data) {
            return body.detail
        }

        struct ObjectDetailBody: Decodable {
            struct DetailObject: Decodable {
                let message: String?
            }

            let detail: DetailObject
        }
        if let body = try? JSONDecoder().decode(ObjectDetailBody.self, from: data),
           let message = body.detail.message,
           !message.isEmpty {
            return message
        }

        struct ValidationIssue: Decodable {
            let msg: String
        }
        struct ArrayDetailBody: Decodable {
            let detail: [ValidationIssue]
        }
        if let body = try? JSONDecoder().decode(ArrayDetailBody.self, from: data) {
            let messages = body.detail.map(\.msg).filter { !$0.isEmpty }
            if !messages.isEmpty {
                return messages.joined(separator: "\n")
            }
        }

        return nil
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
