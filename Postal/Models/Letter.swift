import Foundation

enum LetterFormat: String, Codable, Hashable {
    case text
    case image
    case encoded
}

/// Metadata returned on shipment create and mirrored in Firestore (no bytes).
struct LetterMetadata: Codable, Hashable {
    let format: LetterFormat
    let mimeType: String
    let encoding: String?
    let filename: String?
    let byteSize: Int?

    enum CodingKeys: String, CodingKey {
        case format
        case mimeType = "mime_type"
        case encoding
        case filename
        case byteSize = "byte_size"
    }
}

/// JSON body for `GET /api/shipments/{id}/letter` when format is text.
struct TextLetterResponse: Codable, Hashable {
    let format: LetterFormat
    let mimeType: String
    let encoding: String?
    let text: String

    enum CodingKeys: String, CodingKey {
        case format
        case mimeType = "mime_type"
        case encoding
        case text
    }
}

/// Nested `letter` object for `POST /api/shipments` (text via JSON).
struct CreateTextLetterPayload: Codable, Hashable {
    let format: LetterFormat
    let mimeType: String
    let text: String

    enum CodingKeys: String, CodingKey {
        case format
        case mimeType = "mime_type"
        case text
    }

    static func plain(_ text: String) -> CreateTextLetterPayload {
        CreateTextLetterPayload(format: .text, mimeType: "text/plain", text: text)
    }
}

struct CreateShipmentRequest: Codable {
    let originBoxID: MailboxID
    let destinationBoxID: MailboxID
    let letter: CreateTextLetterPayload?

    enum CodingKeys: String, CodingKey {
        case originBoxID = "origin_box_id"
        case destinationBoxID = "destination_box_id"
        case letter
    }

    init(origin: MailboxSummary, destination: MailboxSummary, letter: CreateTextLetterPayload?) {
        self.originBoxID = origin.id
        self.destinationBoxID = destination.id
        self.letter = letter
    }
}

/// Parts for multipart `POST /api/shipments` (image / encoded letters).
struct CreateMultipartLetterPayload {
    let format: LetterFormat
    let mimeType: String
    let encoding: String?
    let fileData: Data
    let filename: String

    init(format: LetterFormat, mimeType: String, encoding: String? = nil, fileData: Data, filename: String) {
        self.format = format
        self.mimeType = mimeType
        self.encoding = encoding
        self.fileData = fileData
        self.filename = filename
    }
}

struct CreateMultipartShipmentRequest {
    let originBoxID: MailboxID
    let destinationBoxID: MailboxID
    let letter: CreateMultipartLetterPayload?

    init(origin: MailboxSummary, destination: MailboxSummary, letter: CreateMultipartLetterPayload?) {
        self.originBoxID = origin.id
        self.destinationBoxID = destination.id
        self.letter = letter
    }
}

struct ShipmentCreateResponse: Codable, Identifiable, Hashable {
    let id: String
    let trackingNumber: String
    let status: ShipmentStatus
    let originBoxID: MailboxID
    let destinationBoxID: MailboxID
    let letter: LetterMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case trackingNumber = "tracking_number"
        case status
        case originBoxID = "origin_box_id"
        case destinationBoxID = "destination_box_id"
        case letter
    }
}

/// Result of `HEAD /api/shipments/{id}/letter`.
struct LetterProbe: Hashable {
    let contentType: String
    let contentLength: Int?
}

/// Fetched letter bytes, discriminated by format.
enum LetterContent: Hashable {
    case text(String, mimeType: String)
    case image(Data, metadata: LetterMetadata)
    case encoded(Data, metadata: LetterMetadata)

    var format: LetterFormat {
        switch self {
        case .text: .text
        case .image: .image
        case .encoded: .encoded
        }
    }
}
