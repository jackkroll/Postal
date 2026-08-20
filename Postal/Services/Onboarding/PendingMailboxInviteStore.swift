import Foundation
import Observation

/// Queues inbound mailbox invites until the user can confirm adding them.
@Observable
final class PendingMailboxInviteStore {
    /// Mailbox offered for address-book import (deeplink / QR). Cleared on save or dismiss.
    private(set) var offeredMailboxID: MailboxID?

    func offer(_ mailboxID: MailboxID) {
        offeredMailboxID = mailboxID
    }

    func clear() {
        offeredMailboxID = nil
    }

    @discardableResult
    func consume() -> MailboxID? {
        let value = offeredMailboxID
        offeredMailboxID = nil
        return value
    }
}
