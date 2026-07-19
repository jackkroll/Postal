import Foundation

/// Origin or destination of a letter (mailbox id or display label).
struct LetterEndpoint: Hashable {
    /// Usually a mailbox id (`"404:7XK9M"`), sometimes a post-office name or label.
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(mailboxID: MailboxID) {
        self.rawValue = mailboxID.rawValue
    }

    var mailboxID: MailboxID? {
        MailboxID(rawValue: rawValue)
    }

    /// Label available without network enrichment.
    var unresolvedLabel: String {
        if let mailboxID {
            return "Box \(mailboxID.code)"
        }
        return rawValue.isEmpty ? "Unknown" : rawValue
    }
}

/// Endpoint enriched with mailbox and/or location details for display.
struct ResolvedLetterEndpoint: Hashable {
    let endpoint: LetterEndpoint
    let mailbox: MailboxSummary?
    let location: Location?

    var title: String {
        if let mailbox {
            return mailbox.label
        }
        return endpoint.unresolvedLabel
    }

    var locationName: String? {
        mailbox?.postOfficeName ?? location?.name
    }

    var detailLine: String {
        if let locationName {
            return "\(title) · \(locationName)"
        }
        return title
    }
}
