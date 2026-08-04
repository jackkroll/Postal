import Foundation

extension APIClient {
    /// Resolves inbound shipment IDs into letter summaries (best-effort per ID).
    func listInboundLetterSummaries(
        status: ShipmentStatus? = nil,
        limit: Int? = nil
    ) async throws -> [LetterSummary] {
        let response: InboundLettersResponse = try await get(
            .meInboundLetters(status: status, limit: limit),
            authenticated: true
        )
        return try await resolveInboundLetterSummaries(ids: response.letterIDs)
    }

    /// Resolves inbound letter IDs for one owned mailbox into letter summaries.
    func listInboundLetterSummaries(
        mailboxID: MailboxID,
        status: ShipmentStatus? = nil,
        limit: Int? = nil
    ) async throws -> [LetterSummary] {
        let response: InboundLettersResponse = try await get(
            .meMailboxInboundLetters(
                mailboxID: mailboxID.rawValue,
                status: status,
                limit: limit
            ),
            authenticated: true
        )
        return try await resolveInboundLetterSummaries(ids: response.letterIDs)
    }

    private func resolveInboundLetterSummaries(ids: [String]) async throws -> [LetterSummary] {
        guard !ids.isEmpty else { return [] }

        var itemsByID: [String: LetterSummary] = [:]
        itemsByID.reserveCapacity(ids.count)

        await withTaskGroup(of: (String, LetterSummary?).self) { group in
            for id in ids {
                group.addTask {
                    let shipment = try? await self.fetchShipment(id: id)
                    return (id, shipment.map(LetterSummary.init(shipment:)))
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
