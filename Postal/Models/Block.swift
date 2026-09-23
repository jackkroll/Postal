import Foundation

/// Body for `POST /api/me/blocks`.
struct CreateBlockRequest: Codable, Hashable {
    let mailboxID: String

    enum CodingKeys: String, CodingKey {
        case mailboxID = "mailbox_id"
    }
}

/// Response from `GET /api/me/blocks` — only blocks the caller created.
struct BlockListResponse: Codable, Hashable {
    let blocks: [BlockedAddress]
}

/// A block the signed-in user created, from `POST` / `GET /api/me/blocks`.
///
/// The server stores the block against the *person* who owned `mailboxID`, so it
/// covers their other mailboxes and outlives them releasing this one. The blocked
/// user is never identified, and the post office fields go null once the mailbox
/// is released — hence the display fallbacks below.
struct BlockedAddress: Codable, Hashable, Identifiable {
    let id: String
    /// Raw `{post_office_id}:{CODE}` exactly as the server recorded it. Left unparsed
    /// so a released or unexpected address still renders.
    let mailboxID: String
    let postOfficeID: Int?
    let postOfficeName: String?
    let mailboxLabel: String?
    let createdAt: Date
    /// In-transit letters failed by this block, both directions combined.
    /// Only the create response carries it; the list endpoint returns null.
    let cancelledLetters: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case mailboxID = "mailbox_id"
        case postOfficeID = "post_office_id"
        case postOfficeName = "post_office_name"
        case mailboxLabel = "mailbox_label"
        case createdAt = "created_at"
        case cancelledLetters = "cancelled_letters"
    }

    var parsedMailboxID: MailboxID? {
        MailboxID(rawValue: mailboxID)
    }

    var displayLabel: String {
        if let mailboxLabel, !mailboxLabel.isEmpty { return mailboxLabel }
        if let code = parsedMailboxID?.code { return "Box \(code)" }
        return mailboxID
    }

    var locationLabel: String {
        if let postOfficeName, !postOfficeName.isEmpty { return postOfficeName }
        if let postOfficeID = postOfficeID ?? parsedMailboxID?.postOfficeID {
            return "Post office \(postOfficeID)"
        }
        return BlockText.unknownPostOffice
    }

    /// True once the blocked mailbox has been released and the server stopped
    /// resolving its post office. The block itself still stands.
    var isMailboxReleased: Bool {
        postOfficeID == nil && postOfficeName == nil && mailboxLabel == nil
    }

    func matches(_ candidate: MailboxID) -> Bool {
        mailboxID.caseInsensitiveCompare(candidate.rawValue) == .orderedSame
    }
}

/// Structured `detail` on HTTP 403 from `POST /api/shipments` and
/// `GET /api/shipments/estimate` when the two users are blocked.
///
/// Both endpoints also return 403 with a plain *string* detail for unrelated
/// reasons (origin ownership, Plus-only estimates), so this only decodes when
/// `detail` is an object carrying a recognized `code`.
struct SendBlockedDetail: Hashable, Sendable {
    enum Reason: String, Hashable, Sendable {
        /// The signed-in user placed the block, so they can lift it themselves.
        case senderBlockedRecipient = "sender_blocked_recipient"
        /// The other party placed it. Never reveal that a block exists.
        case recipientBlockedSender = "recipient_blocked_sender"
    }

    let reason: Reason
    let message: String?
}

extension SendBlockedDetail: Decodable {
    private enum CodingKeys: String, CodingKey {
        case code
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let code = try container.decode(String.self, forKey: .code)
        guard let reason = Reason(rawValue: code) else {
            throw DecodingError.dataCorruptedError(
                forKey: .code,
                in: container,
                debugDescription: "Unrecognized send denial code '\(code)'."
            )
        }
        self.reason = reason
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

extension Notification.Name {
    /// Letter state changed on the server outside the letters screens — a block
    /// fails in-transit mail in both directions, so cached lists are stale.
    static let postalLettersDidChangeRemotely = Notification.Name("postal.letters.didChangeRemotely")
}
