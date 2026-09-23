import Foundation

/// Server-side limits on `POST /api/me/reports`, enforced locally so an
/// over-long claim never round-trips just to come back as a 422.
enum ReportLimits {
    static let detailsMaxLength = 2000
}

/// Why a report was filed. The server validates against exactly this list, so an
/// unrecognized value is a 422 rather than a stored report.
enum ReportReason: String, Codable, CaseIterable, Hashable, Identifiable {
    case harassment
    case hateSpeech = "hate_speech"
    case sexualContent = "sexual_content"
    case violence
    case spam
    case illegalContent = "illegal_content"
    case other

    var id: String { rawValue }
}

/// Whether a report is a claim about one letter's content or about an address's
/// behavior over time.
enum ReportTargetType: String, Codable, Hashable {
    case letter
    case mailbox
}

/// Body for `POST /api/me/reports`. Exactly one of the two targets may be set —
/// both or neither is a 400.
struct CreateReportRequest: Codable, Hashable {
    let letterID: String?
    let mailboxID: String?
    let reason: ReportReason
    let details: String?

    enum CodingKeys: String, CodingKey {
        case letterID = "letter_id"
        case mailboxID = "mailbox_id"
        case reason
        case details
    }

    static func letter(shipmentID: String, reason: ReportReason, details: String?) -> CreateReportRequest {
        CreateReportRequest(
            letterID: shipmentID,
            mailboxID: nil,
            reason: reason,
            details: normalizedDetails(details)
        )
    }

    static func mailbox(mailboxID: String, reason: ReportReason, details: String?) -> CreateReportRequest {
        CreateReportRequest(
            letterID: nil,
            mailboxID: mailboxID,
            reason: reason,
            details: normalizedDetails(details)
        )
    }

    /// The server trims `details` and stores an empty string as null; matching that
    /// here keeps the local copy of a report identical to the stored one.
    private static func normalizedDetails(_ details: String?) -> String? {
        guard let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return String(trimmed.prefix(ReportLimits.detailsMaxLength))
    }
}

/// Response from `GET /api/me/reports` — only reports the caller filed. A reported
/// user never sees the reports filed against them.
struct ReportListResponse: Codable, Hashable {
    let reports: [SubmittedReport]
}

/// A report the signed-in user filed, from `POST` / `GET /api/me/reports`.
///
/// Deliberately carries no moderation state: the reporter learns that their report
/// was recorded and nothing about whether the target was actioned. Filing one does
/// not stop mail — that takes a separate block.
struct SubmittedReport: Codable, Hashable, Identifiable {
    let id: String
    let targetType: ReportTargetType
    /// The reported shipment; always null on a mailbox report.
    let letterID: String?
    /// On a letter report this is the *sender's* origin box, which is null on
    /// shipments predating origin-box tracking.
    let mailboxID: String?
    let reason: ReportReason
    let details: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case targetType = "target_type"
        case letterID = "letter_id"
        case mailboxID = "mailbox_id"
        case reason
        case details
        case createdAt = "created_at"
    }

    init(
        id: String,
        targetType: ReportTargetType,
        letterID: String?,
        mailboxID: String?,
        reason: ReportReason,
        details: String?,
        createdAt: Date
    ) {
        self.id = id
        self.targetType = targetType
        self.letterID = letterID
        self.mailboxID = mailboxID
        self.reason = reason
        self.details = details
        self.createdAt = createdAt
    }

    /// Decoded leniently on the two enums: a reason or target type added server-side
    /// must not take down the whole list, since this screen only reads reports back.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        letterID = try container.decodeIfPresent(String.self, forKey: .letterID)
        mailboxID = try container.decodeIfPresent(String.self, forKey: .mailboxID)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        reason = ReportReason(rawValue: try container.decode(String.self, forKey: .reason)) ?? .other
        targetType = ReportTargetType(rawValue: try container.decode(String.self, forKey: .targetType))
            ?? (letterID == nil ? .mailbox : .letter)
    }

    var parsedMailboxID: MailboxID? {
        mailboxID.flatMap(MailboxID.init(rawValue:))
    }

    func matches(shipmentID: String) -> Bool {
        letterID == shipmentID
    }

    /// Best-effort, with the same caveat as a block: reports are recorded against the
    /// account, so someone reported through another of their mailboxes has no match.
    func matches(mailboxID candidate: MailboxID) -> Bool {
        guard targetType == .mailbox, let mailboxID else { return false }
        return mailboxID.caseInsensitiveCompare(candidate.rawValue) == .orderedSame
    }
}

/// What a report is about, resolved before the sheet opens.
enum ReportTarget: Hashable, Identifiable {
    /// A letter the caller received. Only its recipient may report it, and only once
    /// it has arrived — a report is a claim about content actually seen.
    case letter(shipmentID: String, sender: MailboxID?, senderLabel: String?)
    /// An address, recorded against whoever owns it today rather than the recyclable
    /// box code, so a later occupant is never implicated.
    case mailbox(MailboxSummary)

    var id: String {
        switch self {
        case let .letter(shipmentID, _, _): "letter:\(shipmentID)"
        case let .mailbox(mailbox): "mailbox:\(mailbox.id.rawValue)"
        }
    }

    var shipmentID: String? {
        guard case let .letter(shipmentID, _, _) = self else { return nil }
        return shipmentID
    }
}

extension MailboxSummary {
    /// A stand-in for an address known only by id — a letter's sender box, or the one
    /// echoed back on a report — so the block confirmation still has something to show.
    static func unresolved(_ id: MailboxID, label: String? = nil) -> MailboxSummary {
        MailboxSummary(
            id: id,
            postOfficeID: id.postOfficeID,
            postOfficeName: nil,
            label: label ?? "Box \(id.code)",
            ownerUserID: nil,
            owned: false
        )
    }
}
