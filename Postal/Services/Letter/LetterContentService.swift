import Foundation

/// Fetches letter bytes from the PostalSim API.
protocol LetterContentProviding: AnyObject {
    func fetchLetter(shipmentID: String, expectedFormat: LetterFormat?) async throws -> LetterContent
    func probeLetter(shipmentID: String) async throws -> LetterProbe
}

final class LetterContentService: LetterContentProviding {
    private let api: APIClient

    init(api: APIClient = AppServices.api) {
        self.api = api
    }

    func fetchLetter(shipmentID: String, expectedFormat: LetterFormat? = nil) async throws -> LetterContent {
        try await api.fetchLetter(shipmentID: shipmentID, expectedFormat: expectedFormat)
    }

    func probeLetter(shipmentID: String) async throws -> LetterProbe {
        try await api.probeLetter(shipmentID: shipmentID)
    }
}
