import Foundation

/// All Plus / stamps / mailbox promotion and limit copy in one place.
enum PromoText {
    // MARK: Plan names

    static let planPlus = "Plus"
    static let planFree = "Free"
    static let planUnknown = "—"

    // MARK: Buttons / labels

    static let upgradeToPlus = "Upgrade to Plus"
    static let manageSubscription = "Manage Subscription"
    static let moreMailboxes = "More Mailboxes"
    static let claimFreeStamps = "Claim Free Stamps"
    static let unlockShipmentDetails = "Unlock shipment details with Plus"
    static let claimStampsToSend = "Claim stamps to send"
    static let plusShort = "Plus"

    static func claimFreeStamps(amount: Int) -> String {
        if amount > 1 {
            "Claim \(amount) free stamps"
        }
        else if amount == 1 {
            "Claim a free stamp"
        } else {
            "Sorry, no free stamps are available"
        }
    }

    // MARK: Settings

    static let accountFooterPlus =
        "Plus includes unlimited sends and more mailboxes. Detailed tracking notifications are unlocked."

    static let accountFooterFree =
        "Free accounts get a periodic stamp allowance. Plus unlocks unlimited sends, more mailboxes, and detailed notifications."

    static func stampsPerSend(_ count: Int) -> String {
        "\(count) stamp\(count == 1 ? "" : "s") per send"
    }

    static func letterSizePlanLabel(isSubscriber: Bool) -> String {
        isSubscriber ? "Plus limits" : "Free limits"
    }

    // MARK: Stamps

    static let unlimitedSendsWithPlus = "Unlimited sends with Plus"
    static let unlimitedSends = "Unlimited"
    static let outOfStamps = "You're out of stamps."

    static func stampBalance(_ count: Int) -> String {
        "\(count) stamp\(count == 1 ? "" : "s")"
    }

    static let stampPhaseClaimOrUpgrade =
        "Claim free stamps, or upgrade to Plus for unlimited sends."

    static let stampPhaseOutOfStamps =
        "You're out of stamps. Upgrade to Plus for unlimited sends."

    static func stampPhaseReady(balanceLabel: String) -> String {
        "\(balanceLabel). Tap the stamp to send."
    }

    static let stampPhaseTapToSend = "Tap the stamp to send."

    static let notEnoughStampsClaimOrUpgrade =
        "Not enough stamps to send. Claim your free allowance or upgrade to Plus."

    static let notEnoughStamps = "Not enough stamps to send a letter."

    // MARK: Mailboxes

    static let mailboxLimitTitle = "Mailbox Limit"
    static let mailboxLimitReachedTitle = "Mailbox Limit Reached"
    static let mailboxLimitReachedFallback = "You've reached your mailbox limit."

    static func mailboxLimitReached(owned: Int, limit: Int, isSubscriber: Bool) -> String {
        var message = "You own \(owned) of \(limit) mailboxes."
        if !isSubscriber {
            message += " Upgrade to Plus for more."
        }
        return message
    }

    static func claimMailboxFooter(owned: Int, limit: Int) -> String {
        "A mailbox at this post office will be assigned to you (\(owned)/\(limit) used)."
    }

    static let claimMailboxFooterFallback =
        "A mailbox at this post office will be assigned to you."

    // MARK: Next claim

    static func nextFreeStampClaim(at timestamp: String) -> String {
        "Next free stamp claim: \(timestamp)"
    }
}
