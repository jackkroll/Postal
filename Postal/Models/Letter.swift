import Foundation

enum LetterFormat: String, Codable, Hashable {
    case text
    case image
    case encoded
    case pkDrawing = "PKDrawing"
}

/// Metadata returned on shipment create and shipment detail (no bytes).
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

struct CreateShipmentRequest: Encodable {
    let originBoxID: MailboxID
    let destinationBoxID: MailboxID
    let letter: CreateTextLetterPayload?
    let schedule: ShipmentSchedule?

    enum CodingKeys: String, CodingKey {
        case originBoxID = "origin_box_id"
        case destinationBoxID = "destination_box_id"
        case letter
        case schedulePreset = "schedule_preset"
        case deliverAt = "deliver_at"
    }

    init(
        origin: MailboxSummary,
        destination: MailboxSummary,
        letter: CreateTextLetterPayload?,
        schedule: ShipmentSchedule? = nil
    ) {
        self.originBoxID = origin.id
        self.destinationBoxID = destination.id
        self.letter = letter
        self.schedule = schedule
    }

    init(
        originBoxID: MailboxID,
        destinationBoxID: MailboxID,
        letter: CreateTextLetterPayload?,
        schedule: ShipmentSchedule? = nil
    ) {
        self.originBoxID = originBoxID
        self.destinationBoxID = destinationBoxID
        self.letter = letter
        self.schedule = schedule
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(originBoxID, forKey: .originBoxID)
        try container.encode(destinationBoxID, forKey: .destinationBoxID)
        try container.encodeIfPresent(letter, forKey: .letter)
        switch schedule {
        case let .preset(preset):
            try container.encode(preset, forKey: .schedulePreset)
        case let .deliverAt(date):
            try container.encode(date.apiTimestampString, forKey: .deliverAt)
        case nil:
            break
        }
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

    static func pkDrawing(_ data: Data) -> CreateMultipartLetterPayload {
        CreateMultipartLetterPayload(
            format: .pkDrawing,
            mimeType: "application/x-pkdrawing",
            fileData: data,
            filename: "letter.pkdrawing"
        )
    }
}

struct CreateMultipartShipmentRequest {
    let originBoxID: MailboxID
    let destinationBoxID: MailboxID
    let letter: CreateMultipartLetterPayload?
    let schedule: ShipmentSchedule?

    init(
        origin: MailboxSummary,
        destination: MailboxSummary,
        letter: CreateMultipartLetterPayload?,
        schedule: ShipmentSchedule? = nil
    ) {
        self.originBoxID = origin.id
        self.destinationBoxID = destination.id
        self.letter = letter
        self.schedule = schedule
    }

    init(
        originBoxID: MailboxID,
        destinationBoxID: MailboxID,
        letter: CreateMultipartLetterPayload?,
        schedule: ShipmentSchedule? = nil
    ) {
        self.originBoxID = originBoxID
        self.destinationBoxID = destinationBoxID
        self.letter = letter
        self.schedule = schedule
    }
}

struct ShipmentCreateResponse: Codable, Identifiable, Hashable {
    let id: String
    let trackingNumber: String
    let status: ShipmentStatus
    let originBoxID: MailboxID
    let destinationBoxID: MailboxID
    let expectedDeliveryTime: Date?
    let scheduledDeliveryAt: Date?
    let letter: LetterMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case trackingNumber = "tracking_number"
        case status
        case originBoxID = "origin_box_id"
        case destinationBoxID = "destination_box_id"
        case expectedDeliveryTime = "expected_delivery_time"
        case scheduledDeliveryAt = "scheduled_delivery_at"
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
    case pkDrawing(Data, metadata: LetterMetadata)

    var format: LetterFormat {
        switch self {
        case .text: .text
        case .image: .image
        case .encoded: .encoded
        case .pkDrawing: .pkDrawing
        }
    }
}
