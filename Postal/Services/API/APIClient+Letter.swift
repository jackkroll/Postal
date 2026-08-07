import Foundation

extension APIClient {
    func createShipment(_ request: CreateShipmentRequest) async throws -> ShipmentCreateResponse {
        try await post(.createShipment, body: request, authenticated: true)
    }

    func createShipmentMultipart(_ request: CreateMultipartShipmentRequest) async throws -> ShipmentCreateResponse {
        let boundary = "PostalBoundary-\(UUID().uuidString)"
        var urlRequest = URLRequest(url: APIEndpoint.createShipment.url(baseURL: baseURL))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = try await tokenProvider?.idToken(forceRefresh: false) {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpBody = Self.multipartBody(for: request, boundary: boundary)

        let (data, response) = try await session.data(for: urlRequest)
        try Self.validateHTTPResponse(response, data: data)

        do {
            return try decoder.decode(ShipmentCreateResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(Self.decodingErrorMessage(error))
        }
    }

    func probeLetter(shipmentID: String) async throws -> LetterProbe {
        let response = try await head(.shipmentLetter(id: shipmentID), authenticated: true)
        return LetterProbe(
            contentType: response.value(forHTTPHeaderField: "Content-Type") ?? "",
            contentLength: response.value(forHTTPHeaderField: "Content-Length").flatMap(Int.init)
        )
    }

    func fetchLetter(shipmentID: String, expectedFormat: LetterFormat? = nil) async throws -> LetterContent {
        let (data, response) = try await fetchData(.shipmentLetter(id: shipmentID), authenticated: true)
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? ""
        let filename = Self.filename(from: response)

        if expectedFormat == .text || (expectedFormat == nil && contentType.contains("application/json")) {
            let textLetter = try decoder.decode(TextLetterResponse.self, from: data)
            return .text(textLetter.text, mimeType: textLetter.mimeType)
        }

        // Prefer content sniffing over server metadata — hosts that don't know PKDrawing
        // often store these as generic "encoded" while still serving letter.pkdrawing.
        let inferredFormat = Self.resolveLetterFormat(
            expectedFormat: expectedFormat,
            contentType: contentType,
            filename: filename
        )

        let mimeType = contentType.split(separator: ";").first.map(String.init) ?? contentType
        let metadata = LetterMetadata(
            format: inferredFormat,
            mimeType: mimeType.isEmpty ? (expectedFormat == .pkDrawing ? "application/x-pkdrawing" : mimeType) : mimeType,
            encoding: nil,
            filename: filename,
            byteSize: data.count
        )

        switch metadata.format {
        case .image:
            return .image(data, metadata: metadata)
        case .pkDrawing:
            return .pkDrawing(data, metadata: metadata)
        case .encoded, .text:
            return .encoded(data, metadata: metadata)
        }
    }

    func head(_ endpoint: APIEndpoint, authenticated: Bool = false) async throws -> HTTPURLResponse {
        var request = URLRequest(url: endpoint.url(baseURL: baseURL))
        request.httpMethod = "HEAD"

        if authenticated, let token = try await tokenProvider?.idToken(forceRefresh: false) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        try Self.validateHTTPResponse(httpResponse, data: nil)
        return httpResponse
    }

    func fetchData(_ endpoint: APIEndpoint, authenticated: Bool = false) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: endpoint.url(baseURL: baseURL))
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated, let token = try await tokenProvider?.idToken(forceRefresh: false) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        try Self.validateHTTPResponse(httpResponse, data: data)
        return (data, httpResponse)
    }

    private static func validateHTTPResponse(_ response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = data.flatMap { APIClient.apiErrorDetail(from: $0) ?? String(data: $0, encoding: .utf8) }
            throw APIError.httpStatus(httpResponse.statusCode, message, body: data)
        }
    }

    private static func filename(from response: HTTPURLResponse) -> String? {
        guard let disposition = response.value(forHTTPHeaderField: "Content-Disposition") else { return nil }
        let pattern = #"filename="([^"]+)""#
        guard let range = disposition.range(of: pattern, options: .regularExpression) else { return nil }
        let match = disposition[range]
        return match
            .replacingOccurrences(of: "filename=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    /// Resolves display/decode format. Filename and content-type win over a generic
    /// server `encoded` tag so PKDrawing payloads remain viewable before server support lands.
    private static func resolveLetterFormat(
        expectedFormat: LetterFormat?,
        contentType: String,
        filename: String?
    ) -> LetterFormat {
        if looksLikePKDrawing(contentType: contentType, filename: filename, expectedFormat: expectedFormat) {
            return .pkDrawing
        }
        if let expectedFormat {
            return expectedFormat
        }
        if contentType.hasPrefix("image/") {
            return .image
        }
        return .encoded
    }

    private static func looksLikePKDrawing(
        contentType: String,
        filename: String?,
        expectedFormat: LetterFormat?
    ) -> Bool {
        if expectedFormat == .pkDrawing {
            return true
        }
        let type = contentType.lowercased()
        if type.contains("pkdrawing") || type.contains("pencilkit") {
            return true
        }
        if let filename, filename.lowercased().hasSuffix(".pkdrawing") {
            return true
        }
        return false
    }

    private static func multipartBody(for request: CreateMultipartShipmentRequest, boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            body.append("\(value)\(lineBreak)".data(using: .utf8)!)
        }

        appendField("origin_box_id", request.originBoxID.rawValue)
        appendField("destination_box_id", request.destinationBoxID.rawValue)

        switch request.schedule {
        case let .preset(preset):
            appendField("schedule_preset", preset.rawValue)
        case let .deliverAt(date):
            appendField("deliver_at", date.apiTimestampString)
        case nil:
            break
        }

        if let letter = request.letter {
            appendField("letter_format", letter.format.rawValue)
            appendField("letter_mime_type", letter.mimeType)
            if let encoding = letter.encoding {
                appendField("letter_encoding", encoding)
            }

            body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"letter_file\"; filename=\"\(letter.filename)\"\(lineBreak)"
                    .data(using: .utf8)!
            )
            body.append("Content-Type: \(letter.mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            body.append(letter.fileData)
            body.append(lineBreak.data(using: .utf8)!)
        }

        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }
}
