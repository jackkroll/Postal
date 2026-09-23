import Foundation

extension APIClient {
    func listOwnedMailboxes() async throws -> [MailboxSummary] {
        let response: OwnedMailboxesResponse = try await get(.meMailboxes, authenticated: true)
        return response.mailboxes
    }

    func claimMailbox(postOfficeID: Int) async throws -> MailboxSummary {
        try await post(
            .claimMailbox,
            body: try ClaimMailboxRequest(postOfficeID: postOfficeID),
            authenticated: true
        )
    }

    func relinquishMailboxPreview(mailboxID: MailboxID) async throws -> RelinquishMailboxPreview {
        try await get(
            .relinquishMailboxPreview(mailboxID: mailboxID.rawValue),
            authenticated: true
        )
    }

    func relinquishMailbox(mailboxID: MailboxID) async throws {
        try await delete(
            .deleteMailbox(mailboxID: mailboxID.rawValue),
            authenticated: true
        )
    }

    /// `GET /api/mailboxes/validate` — whether the address exists and is owned.
    /// Independent of blocking: a blocked person's address is still valid.
    func validateMailbox(mailboxID: MailboxID) async throws -> Bool {
        let response: ValidationResponse = try await get(
            .validateMailbox(mailboxID: mailboxID.rawValue),
            authenticated: true
        )
        return response.valid
    }

    func listPostOffices(search: String? = nil, limit: Int? = nil) async throws -> [PostOffice] {
        // Mirror shipments clamp so an oversized limit cannot 422 the endpoint.
        let resolvedLimit = max(min(limit ?? 100, 100), 1)
        return try await get(
            .postOffices(search: search, limit: resolvedLimit),
            authenticated: true
        )
    }

    func lookupMailbox(postOffice: PostOffice, code: String) async throws -> MailboxSummary {
        guard PostOfficeValidation.isValidID(postOffice.id) else {
            throw MailboxLookupError.invalidPostOfficeID(postOffice.id)
        }

        let normalized = MailboxCodeValidation.normalized(code)
        guard MailboxCodeValidation.isValid(normalized) else {
            throw MailboxLookupError.invalidMailboxCode(normalized)
        }

        guard let mailboxID = MailboxID(postOfficeID: postOffice.id, code: normalized) else {
            throw MailboxLookupError.invalidMailboxCode(normalized)
        }

        async let postOfficeResponse: ValidationResponse = get(
            .validatePostOffice(postOfficeID: postOffice.id),
            authenticated: true
        )
        async let isKnownMailbox: Bool = validateMailbox(mailboxID: mailboxID)

        guard try await postOfficeResponse.valid else {
            throw MailboxLookupError.invalidPostOfficeID(postOffice.id)
        }
        guard try await isKnownMailbox else {
            throw MailboxLookupError.notFound(code: mailboxID.code)
        }

        return MailboxSummary(
            id: mailboxID,
            postOfficeID: postOffice.id,
            postOfficeName: postOffice.name,
            label: "Box \(mailboxID.code)",
            ownerUserID: nil,
            owned: true
        )
    }

    func fetchLocation(code: Int) async throws -> Location {
        try await get(.location(code: code), authenticated: true)
    }

    func listShipments(status: ShipmentStatus? = nil, limit: Int? = nil) async throws -> [Shipment] {
        let resolvedLimit = max(min(limit ?? 100, 500), 1)
        return try await get(
            .listShipments(status: status, limit: resolvedLimit),
            authenticated: true
        )
    }

    func fetchShipment(id: String) async throws -> Shipment {
        try await get(.shipmentDetail(id: id), authenticated: true)
    }

    /// Natural ETA for a route (`GET /api/shipments/estimate`). Plus / `route_estimate` only.
    func estimateShipment(
        originBoxID: MailboxID,
        destinationBoxID: MailboxID
    ) async throws -> ShipmentEstimate {
        try await get(
            .estimateShipment(
                originBoxID: originBoxID.rawValue,
                destinationBoxID: destinationBoxID.rawValue
            ),
            authenticated: true
        )
    }

    func fetchShipmentEvents(id: String) async throws -> [ShipmentTrackingEvent] {
        try await get(.shipmentEvents(id: id), authenticated: true)
    }
}
