import Foundation

/// Sent-letter row model derived from `GET /api/shipments`.
struct LetterSummary: Identifiable, Hashable {
    let trackingNumber: String
    let shipmentID: String
    let origin: LetterEndpoint
    let destination: LetterEndpoint
    let status: ShipmentStatus
    let hasLetter: Bool
    let letterFormat: LetterFormat?
    let letterMimeType: String?
    let letterEncoding: String?
    let letterByteSize: Int?
    let createdAt: Date?
    let updatedAt: Date?

    var id: String { trackingNumber }

    var letterMetadata: LetterMetadata? {
        guard hasLetter, let letterFormat, let letterMimeType else { return nil }
        return LetterMetadata(
            format: letterFormat,
            mimeType: letterMimeType,
            encoding: letterEncoding,
            filename: nil,
            byteSize: letterByteSize
        )
    }

    var sortDate: Date {
        updatedAt ?? createdAt ?? .distantPast
    }

    init(
        trackingNumber: String,
        shipmentID: String? = nil,
        origin: LetterEndpoint,
        destination: LetterEndpoint,
        status: ShipmentStatus,
        hasLetter: Bool,
        letterFormat: LetterFormat?,
        letterMimeType: String?,
        letterEncoding: String?,
        letterByteSize: Int?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.trackingNumber = trackingNumber
        self.shipmentID = shipmentID ?? trackingNumber
        self.origin = origin
        self.destination = destination
        self.status = status
        self.hasLetter = hasLetter
        self.letterFormat = letterFormat
        self.letterMimeType = letterMimeType
        self.letterEncoding = letterEncoding
        self.letterByteSize = letterByteSize
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(shipment: Shipment) {
        trackingNumber = shipment.trackingNumber
        shipmentID = shipment.id
        origin = shipment.originEndpoint
        destination = shipment.destinationEndpoint
        status = shipment.status
        hasLetter = shipment.letter != nil
        letterFormat = shipment.letter?.format
        letterMimeType = shipment.letter?.mimeType
        letterEncoding = shipment.letter?.encoding
        letterByteSize = shipment.letter?.byteSize
        createdAt = shipment.createdAt ?? shipment.requestedAt
        updatedAt = shipment.updatedAt ?? shipment.requestedAt
    }
}
