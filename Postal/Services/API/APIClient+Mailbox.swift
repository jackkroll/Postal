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
        async let mailboxResponse: ValidationResponse = get(
            .validateMailbox(mailboxID: mailboxID.rawValue),
            authenticated: true
        )

        guard try await postOfficeResponse.valid else {
            throw MailboxLookupError.invalidPostOfficeID(postOffice.id)
        }
        guard try await mailboxResponse.valid else {
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
}
