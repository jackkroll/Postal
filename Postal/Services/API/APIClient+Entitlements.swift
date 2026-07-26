import Foundation

extension APIClient {
    func getEntitlements() async throws -> UserEntitlements {
        try await get(.meEntitlements, authenticated: true)
    }

    /// Claims the periodic stamp allowance (`POST` with no body).
    func claimStampAllowance() async throws -> StampAllowanceClaimResponse {
        try await postEmpty(.claimStampAllowance, authenticated: true)
    }
}
