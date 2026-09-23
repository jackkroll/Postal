import Foundation

/// Copy for blocking addresses. Server `detail` strings are internal and are not
/// surfaced verbatim — except the self-block message, which is written for users.
enum BlockText {
    // MARK: Screen

    static let screenTitle = "Blocked Addresses"
    static let settingsSection = "Privacy"

    static let emptyTitle = "Nobody Blocked"
    static let emptyBody =
        "Blocking an address stops letters in both directions between you and the person who owns it."

    static let listFooter =
        "A block covers every mailbox that person has, now and later, even if they give this one up."

    static let addAction = "Block an Address"
    static let chooseAddressTitle = "Choose Address"
    static let badge = "Blocked"

    static func blockedOn(_ date: Date) -> String {
        "Blocked \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    static let releasedMailbox = "This mailbox has since been released. The block still applies."

    static let unknownPostOffice = "Unknown post office"

    // MARK: Block confirmation

    static let confirmTitle = "Block Address"
    static let confirmAction = "Block"
    static let confirmBody =
        "Letters already on their way between you two are returned right now, in both directions, and neither of you can send to the other again."
    static let confirmScope =
        "This blocks the person who owns the address, including any other mailboxes they have now or claim later."
    static let confirmUndo = "You can unblock from Settings at any time."

    /// Re-blocking returns the original record, which may name a different mailbox
    /// of the same person. Saying so explains why the list shows another address.
    static func alreadyBlocked(as mailboxID: String) -> String {
        "You already blocked this person. They're on your list as \(mailboxID)."
    }

    /// Toast after a successful block. `cancelledLetters` counts both directions.
    static func blockedConfirmation(cancelledLetters: Int) -> String {
        switch cancelledLetters {
        case ..<1:
            return "Blocked. No letters were in transit."
        case 1:
            return "Blocked. 1 letter was returned."
        default:
            return "Blocked. \(cancelledLetters) letters were returned."
        }
    }

    // MARK: Unblock confirmation

    static let unblockTitle = "Unblock Address?"
    static let unblockAction = "Unblock"
    static let unblockBody =
        "You'll both be able to send again right away. Letters that were already returned stay failed, and the stamps refunded for them aren't charged again."

    // MARK: Errors

    /// The server's own wording — already appropriate for users.
    static let selfBlock = "You cannot block your own mailbox."
    static let unknownMailbox = "No one owns that address, so there's nobody to block."
    static let blockFailed = "Couldn't block that address. Try again."
    static let unblockFailed = "Couldn't unblock that address. Try again."

    // MARK: Send-time denial

    static let sendDeniedByYou = "You blocked this address. Unblock it to send this letter."
    /// Deliberately says nothing about a block — the recipient's block stays private.
    static let sendDeniedByRecipient = "This letter can't be delivered to that address."
    static let manageBlockedAction = "Blocked Addresses"

    static func sendDenied(_ reason: SendBlockedDetail.Reason) -> String {
        switch reason {
        case .senderBlockedRecipient: sendDeniedByYou
        case .recipientBlockedSender: sendDeniedByRecipient
        }
    }
}
