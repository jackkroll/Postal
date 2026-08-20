import Foundation

extension APIClient {
    /// Public mailbox invite details for sharing / address-book import.
    func fetchMailboxInvite(mailboxID: MailboxID) async throws -> MailboxInvite {
        try await get(
            .mailboxInvite(mailboxID: mailboxID.rawValue),
            authenticated: false
        )
    }
}
