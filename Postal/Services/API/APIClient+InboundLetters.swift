import Foundation

extension APIClient {
    /// Resolves inbound shipment IDs into display rows (best-effort per ID).
    func listInboundLetterItems(
        status: ShipmentStatus? = nil,
        limit: Int? = nil
    ) async throws -> [InboundLetterItem] {
        let response: InboundLettersResponse = try await get(
            .meInboundLetters(status: status, limit: limit),
            authenticated: true
        )
        return try await resolveInboundLetterItems(ids: response.letterIDs)
    }

    /// Resolves inbound letter IDs for one owned mailbox into display rows.
    func listInboundLetterItems(
        mailboxID: MailboxID,
        status: ShipmentStatus? = nil,
        limit: Int? = nil
    ) async throws -> [InboundLetterItem] {
        let response: InboundLettersResponse = try await get(
            .meMailboxInboundLetters(
                mailboxID: mailboxID.rawValue,
                status: status,
                limit: limit
            ),
            authenticated: true
        )
        return try await resolveInboundLetterItems(ids: response.letterIDs)
    }

    private func resolveInboundLetterItems(ids: [String]) async throws -> [InboundLetterItem] {
        guard !ids.isEmpty else { return [] }

        var itemsByID: [String: InboundLetterItem] = [:]
        itemsByID.reserveCapacity(ids.count)

        await withTaskGroup(of: (String, InboundLetterItem?).self) { group in
            for id in ids {
                group.addTask {
                    let shipment = try? await self.fetchShipment(id: id)
                    return (id, shipment.map(InboundLetterItem.init(shipment:)))
                }
            }

            for await (id, item) in group {
                if let item {
                    itemsByID[id] = item
                }
            }
        }

        return ids.compactMap { itemsByID[$0] }
            .sorted { $0.sortDate > $1.sortDate }
    }

    func listSentLetterSummaries(
        status: ShipmentStatus? = nil,
        limit: Int? = nil
    ) async throws -> [LetterSummary] {
        async let shipmentsTask = listShipments(status: status, limit: limit)
        async let ownedMailboxesTask = listOwnedMailboxes()

        let ownedMailboxIDs = Set(try await ownedMailboxesTask.map(\.id))
        let shipments = try await shipmentsTask

        return shipments
            .filter { shipment in
                guard let originBoxID = shipment.originBoxID else { return false }
                return ownedMailboxIDs.contains(originBoxID)
            }
            .map(LetterSummary.init(shipment:))
            .sorted { $0.sortDate > $1.sortDate }
    }
}
