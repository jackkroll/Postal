import Foundation

extension APIClient {
    /// Oldest first. Only blocks the caller created.
    ///
    /// Blocks share a 120/min per-user bucket, so a 429 means a burst rather than
    /// misuse — hence the backoff on every call here.
    func listBlocks() async throws -> [BlockedAddress] {
        let response: BlockListResponse = try await retryingRateLimit {
            try await self.get(.meBlocks, authenticated: true)
        }
        return response.blocks
    }

    /// Blocks the person who owns `mailboxID`.
    ///
    /// Re-blocking an already-blocked person still returns 201 with the *original*
    /// record — a different `mailboxID` than the one sent when the first block used
    /// another of their addresses — so callers should render what comes back.
    func createBlock(mailboxID: String) async throws -> BlockedAddress {
        try await retryingRateLimit {
            try await self.post(
                .createBlock,
                body: CreateBlockRequest(mailboxID: mailboxID),
                authenticated: true
            )
        }
    }

    func deleteBlock(id: String) async throws {
        try await retryingRateLimit {
            try await self.delete(.deleteBlock(id: id), authenticated: true)
        }
    }
}