import Foundation

/// Copy for reporting abusive content. Server `detail` strings are internal and are
/// not surfaced verbatim, including the ones this file paraphrases — the API's
/// wording exists for clients, not for readers.
enum ReportText {
    // MARK: Screen

    static let screenTitle = "Reports You Filed"
    static let settingsFooter =
        "Reporting sends content to us for review. Blocking stops mail, you can do either, or both."

    static let emptyTitle = "Nothing Reported"
    static let emptyBody =
        "Reporting a letter or an address sends it to us for review. It doesn't stop mail on its own."

    static let listFooter =
        "We review every report. We can't tell you the outcome, and nothing here changes what mail you receive."

    static let badge = "Reported"

    static func reportedOn(_ date: Date) -> String {
        "Reported \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    static let letterTargetLabel = "A letter you received"
    static let mailboxTargetLabel = "An address"
    static let unknownSender = "Sender unknown"

    // MARK: Report form

    static let action = "Report"
    static let letterFormTitle = "Report Letter"
    static let mailboxFormTitle = "Report Address"
    static let submitAction = "Submit Report"
    static let submittingLabel = "Sending…"

    static let reasonSectionTitle = "Reason"
    static let detailsSectionTitle = "Details"
    static let detailsPlaceholder = "What happened? (optional)"
    static let detailsFooter = "Anything you add here goes to the reviewer. Leave it blank if you'd rather not."

    /// Says plainly that a report is not enforcement, so nobody files one expecting
    /// the mail to stop.
    static let independenceNote =
        "A report goes to us for review. It doesn't return letters already on their way, and it doesn't stop this person from sending letters to you."

    static func detailsRemaining(_ count: Int) -> String {
        "\(count) characters left"
    }

    /// Footer where a letter offers both actions at once.
    static let letterActionsFooter =
        "Reporting sends this letter to us for review and changes nothing about your mail. Blocking returns anything in transit between you two and stops future letters."

    // MARK: Filed

    static let filedTitle = "Report Sent"
    static let filedBody =
        "Thanks, a reviewer will take a look. Thank you for helping keep Penpal a safe place"
    static let alreadyFiledTitle = "Already Reported"
    static let alreadyFiledBody =
        "You reported this before, so we kept your original report"

    static let doneAction = "Done"

    // MARK: Cross-suggestion

    /// Shown after a report, since reporting deliberately changes nothing about mail.
    static let alsoBlockTitle = "Want to stop their mail too?"
    static let alsoBlockBody =
    "Blocking prevents you from recieving letters from this user and will stop any letters in transit"
    
    static let alsoBlockAction = "Block Them Too"
    static let alsoBlockUnavailable =
        "We couldn't tell which address this letter came from, so there's nothing to block from here. You can block an address from Settings."

    /// Shown after a block, since a block is private and creates no moderation record.
    static let alsoReportTitle = "Want us to review it?"
    static let alsoReportBody =
        "If what they sent was abusive, you can report it"
    static let alsoReportAction = "Report Them Too"

    /// Reporting and blocking share one sheet, so they share the alert that reports
    /// the refusals caught before it opens.
    static let actionAlertTitle = "Can’t Do That"

    // MARK: Reasons

    static func reasonTitle(_ reason: ReportReason) -> String {
        switch reason {
        case .harassment: "Harassment"
        case .hateSpeech: "Hate Speech"
        case .sexualContent: "Sexual Content"
        case .violence: "Violence or Threats"
        case .spam: "Spam"
        case .illegalContent: "Illegal Content"
        case .other: "Something Else"
        }
    }

    static func reasonDetail(_ reason: ReportReason) -> String {
        switch reason {
        case .harassment: "Targeted at you, repeated, or meant to intimidate."
        case .hateSpeech: "Attacks someone over who they are."
        case .sexualContent: "Explicit material, or anything sexual you didn't ask for."
        case .violence: "Threatens harm to you or someone else."
        case .spam: "Advertising, scams, or bulk mail."
        case .illegalContent: "Breaks the law."
        case .other: "Describe it below so a reviewer knows what to look at."
        }
    }

    // MARK: Errors

    static let selfLetter = "You can't report a letter you sent."
    static let selfMailbox = "That's your own address."
    static let notArrived = "You can report this once it arrives and you've read it."
    static let unknownMailbox = "Nobody owns that address, so there's nothing to report."
    static let letterNotFound = "We couldn't find that letter."
    static let rateLimited = "You've filed several reports just now. Give it a minute and try again."
    static let reportFailed = "Couldn't send that report. Try again."
}
