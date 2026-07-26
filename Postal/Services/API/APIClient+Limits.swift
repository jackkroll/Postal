import Foundation

extension APIClient {
    /// Current letter size ceilings for the signed-in user (`GET /api/me/limits`).
    func getLimits() async throws -> LetterLimits {
        try await get(.meLimits, authenticated: true)
    }
}
