import Foundation

/// Letter row model derived from a shipment (`GET /api/shipments` or inbound ID resolution).
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
    let canReadLetter: Bool
    /// Scheduled arrival from shipment / public track (`expected_delivery_time` / `expectedDeliveryTime`).
    let expectedDeliveryTime: Date?
    /// User-requested hold end; `nil` when not scheduled.
    let scheduledDeliveryAt: Date?
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

    /// Local display for scheduled arrival; `nil` means ETA unavailable.
    var expectedArrivalDisplay: String? {
        guard let expectedDeliveryTime else { return nil }
        return expectedDeliveryTime.formatted(date: .abbreviated, time: .omitted)
    }

    /// Whether this letter is waiting at the destination office for unlock.
    var isHeld: Bool { status == .held }

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
        canReadLetter: Bool = false,
        expectedDeliveryTime: Date? = nil,
        scheduledDeliveryAt: Date? = nil,
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
        self.canReadLetter = canReadLetter
        self.expectedDeliveryTime = expectedDeliveryTime
        self.scheduledDeliveryAt = scheduledDeliveryAt
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
        canReadLetter = shipment.canReadLetter
        expectedDeliveryTime = shipment.expectedDeliveryTime
        scheduledDeliveryAt = shipment.scheduledDeliveryAt
        createdAt = shipment.createdAt ?? shipment.requestedAt
        updatedAt = shipment.updatedAt ?? shipment.requestedAt
    }

    /// Merges public tracking summary onto an existing letter row without dropping mailbox endpoints.
    func attaching(tracking: TrackingInfo) -> LetterSummary {
        LetterSummary(
            trackingNumber: tracking.trackingNumber,
            shipmentID: shipmentID,
            origin: origin,
            destination: destination,
            status: tracking.status,
            hasLetter: hasLetter,
            letterFormat: letterFormat,
            letterMimeType: letterMimeType,
            letterEncoding: letterEncoding,
            letterByteSize: letterByteSize,
            canReadLetter: canReadLetter,
            expectedDeliveryTime: tracking.expectedDeliveryTime,
            scheduledDeliveryAt: scheduledDeliveryAt,
            createdAt: createdAt,
            updatedAt: tracking.updatedAt
        )
    }
}
