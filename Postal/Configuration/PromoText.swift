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

    static func stampCostForLetter(_ count: Int) -> String {
        "\(count) stamp\(count == 1 ? "" : "s") for this letter"
    }

    static func stampCount(_ count: Int) -> String {
        "\(count) stamp\(count == 1 ? "" : "s")"
    }

    /// Composer headline when the letter crosses into another stamp.
    static func usingStampCount(_ count: Int) -> String {
        if count <= 1 {
            return stampCount(1)
        }
        return "Using \(count) stamps"
    }

    /// Settings summary of the size-based tariff.
    static func stampPricingSummary(_ pricing: StampPricing) -> String {
        "From \(pricing.minStamps) · by letter size"
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

    static let stampPhaseReviewSend =
        "Choose postage and when this letter should arrive."

    static let stampPhaseTapToSend = "Tap the stamp to send."

    static let notEnoughStampsClaimOrUpgrade =
        "Not enough stamps to send. Claim your free allowance or upgrade to Plus."

    static let notEnoughStamps = "Not enough stamps to send a letter."

    // MARK: Send confirmation

    static let sendConfirmationTitle = "Confirm Send"
    static let sendConfirmationAction = "Done"
    static let sendBillingSection = "Postage"
    static let sendBillingPostage = "This letter"
    static let sendBillingBalance = "Your balance"
    static let sendBillingAfterSend = "After sending"
    static let sendTimingSection = "Delivery"
    static let sendTimingRequired = "Choose when this letter can be opened."
    static let sendTimingNatural = "As soon as it arrives"
    static let sendTimingNaturalDetail = "No hold, delivered on the natural route."
    static let sendTimingPresetDetail = "Held at the destination until that morning."
    static let sendTimingCustom = "Choose a date & time"
    static let sendTimingCustomDetail = "Plus, unlock at an exact time."
    static let sendTimingCustomLockedDetail = "Upgrade to Plus to unlock an exact time."
    static let sendTimingCustomPicker = "Unlock at"
    static let sendTimingEstimateLoading = "Checking the route…"
    static let sendConfirmationReopen = "Postage & delivery"
    static let sendConfirmationEdit = "Edit postage & delivery"

    static func sendTimingPreset(_ preset: SchedulePreset) -> String {
        switch preset {
        case .oneWeek: "In 1 week"
        case .oneMonth: "In 1 month"
        case .oneYear: "In 1 year"
        }
    }

    static func sendTimingNaturalETA(_ date: Date) -> String {
        "Natural arrival around \(date.formatted(date: .abbreviated, time: .shortened)). Holds must be on or after that time."
    }

    static let sendTimingHoldTooEarly =
        "Choose a time on or after the natural arrival."

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

    // MARK: Onboarding

    static let onboardingSkip = "Skip for now"
    static let onboardingSkipConfirm = "Skip the rest of setup"
    static let onboardingSkipCancel = "Cancel"

    static let onboardingClaimTitle = "Claim your mailbox"
    static let onboardingClaimBody =
        "Pick a post office and we’ll assign you a box. You can claim a different one later anytime."
    static let onboardingClaimFooter =
        "You can claim a different mailbox later from Address Book."

    static let onboardingDestinationTitle = "Anyone to write to?"
    static let onboardingDestinationBody =
        "If you already know a mailbox from a friend, partner, or somewhere you’d like to send a letter feel free to add it now. You can always add people later."
    static let onboardingDestinationYes = "Yes, I have a destination"
    static let onboardingDestinationNo = "Not yet"

    static let onboardingLetterTitle = "Write a time capsule"
    static let onboardingLetterBody =
        "Letters are how Postal works. Start with a note to your future self, or send it to someone you’ve saved."
    static let onboardingLetterToSelf = "To my mailbox"
    static let onboardingLetterOpenAfter = "Open after"
    static let onboardingLetterSending = "Sending…"
    static let onboardingLetterSentTitle = "Time capsule sent"
    static let onboardingLetterNeedsStampsTitle = "Almost there"
    static let onboardingLetterNeedsStampsBody =
        "Your letter is saved on this device. Claim your free stamps next, then you can send it."

    static func onboardingLetterSentBody(preset: SchedulePreset, scheduledAt: Date?) -> String {
        let hold = PromoText.sendTimingPreset(preset).lowercased()
        if let scheduledAt {
            return "It’ll stay sealed until \(scheduledAt.formatted(date: .abbreviated, time: .omitted)) (\(hold)). You’ll find it in My Letters."
        }
        return "It’ll stay sealed \(hold). You’ll find it in My Letters."
    }

    static let onboardingStampsTitle = "Claim your stamps"
    static let onboardingStampsBody =
        "Free accounts get a periodic stamp allowance. Claim yours now so you’re ready to send when you are."
    static let onboardingStampsContinue = "Continue"
    static let onboardingStampsAlreadyClaimed =
        "You’re all set for now. Come back later for your next free claim, or upgrade to Plus for unlimited sends."

    static let onboardingPaywallTitle = "Postal Plus"
    static let onboardingPaywallBody =
        "Unlimited sends, more mailboxes, and richer tracking. No pressure, you can explore free whenever you like."
}
