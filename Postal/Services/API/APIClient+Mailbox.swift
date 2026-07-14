import Foundation

extension APIClient {
    func listOwnedMailboxes() async throws -> [MailboxSummary] {
        try await get(.meMailboxes, authenticated: true)
    }

    func claimMailbox(postOfficeID: Int) async throws -> MailboxSummary {
        try await post(
            .claimMailbox,
            body: ClaimMailboxRequest(postOfficeID: postOfficeID),
            authenticated: true
        )
    }

    func listPostOffices(search: String? = nil, limit: Int? = nil) async throws -> [PostOffice] {
        try await get(.postOffices(search: search, limit: limit), authenticated: true)
    }

    func listMailboxes(postOfficeID: Int) async throws -> [MailboxSummary] {
        try await get(.postOfficeMailboxes(postOfficeID: postOfficeID), authenticated: true)
    }

    func lookupMailbox(postOfficeID: Int, code: String) async throws -> MailboxSummary {
        let mailboxID = MailboxID(postOfficeID: postOfficeID, code: code)
        guard !mailboxID.code.isEmpty else {
            throw MailboxLookupError.notFound(code: code)
        }

        let mailboxes = try await listMailboxes(postOfficeID: postOfficeID)
        guard let mailbox = mailboxes.first(where: { $0.id == mailboxID }) else {
            throw MailboxLookupError.notFound(code: mailboxID.code)
        }
        return mailbox
    }

    func fetchLocation(code: Int) async throws -> Location {
        try await get(.location(code: code), authenticated: true)
    }

    func listShipments(status: ShipmentStatus? = nil, limit: Int? = nil) async throws -> [Shipment] {
        let response: ShipmentListResponse = try await get(
            .listShipments(status: status, limit: limit),
            authenticated: true
        )
        return response.shipments
    }

    func fetchShipment(id: String) async throws -> Shipment {
        try await get(.shipmentDetail(id: id), authenticated: true)
    }
}
