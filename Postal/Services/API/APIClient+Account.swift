import Foundation

extension APIClient {
    /// Deletes the signed-in account and associated PostalSim data (`DELETE /api/me`).
    func deleteMyAccount() async throws {
        try await delete(.deleteMyAccount, authenticated: true)
    }
}
