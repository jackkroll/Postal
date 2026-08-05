import Foundation

/// Response from `GET /api/me/mailboxes`.
struct OwnedMailboxesResponse: Codable, Hashable {
    let mailboxes: [MailboxSummary]
}

/// Response from mailbox/post-office validate endpoints.
struct ValidationResponse: Codable, Hashable {
    let valid: Bool
}

/// Body for `POST /api/me/mailboxes` — claims an available mailbox at a post office.
struct ClaimMailboxRequest: Codable, Hashable {
    let postOfficeID: Int

    enum CodingKeys: String, CodingKey {
        case postOfficeID = "post_office_id"
    }

    init(postOfficeID: Int) throws {
        guard PostOfficeValidation.isValidID(postOfficeID) else {
            throw MailboxLookupError.invalidPostOfficeID(postOfficeID)
        }
        self.postOfficeID = postOfficeID
    }
}

/// Response from `GET /api/me/mailboxes/{mailbox_id}/relinquish-preview`.
struct RelinquishMailboxPreview: Codable, Hashable {
    let mailboxID: MailboxID
    let inboundLetters: [RelinquishInboundLetter]
    let willFailCount: Int

    enum CodingKeys: String, CodingKey {
        case mailboxID = "mailbox_id"
        case inboundLetters = "inbound_letters"
        case willFailCount = "will_fail_count"
    }
}

struct RelinquishInboundLetter: Codable, Identifiable, Hashable {
    let id: String
    let status: ShipmentStatus
    let willFail: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case willFail = "will_fail"
    }
}

struct MailboxSummary: Codable, Identifiable, Hashable {
    let id: MailboxID
    let postOfficeID: Int
    let postOfficeName: String?
    let label: String
    let ownerUserID: String?
    let owned: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case postOfficeID = "post_office_id"
        case postOfficeName = "post_office_name"
        case label
        case ownerUserID = "owner_user_id"
        case owned
    }

    init(
        id: MailboxID,
        postOfficeID: Int,
        postOfficeName: String?,
        label: String,
        ownerUserID: String?,
        owned: Bool
    ) {
        self.id = id
        self.postOfficeID = postOfficeID
        self.postOfficeName = postOfficeName
        self.label = label
        self.ownerUserID = ownerUserID
        self.owned = owned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try container.decode(MailboxID.self, forKey: .id)
        let decodedPostOfficeID = try container.decode(Int.self, forKey: .postOfficeID)
        id = decodedID
        postOfficeID = decodedPostOfficeID
        postOfficeName = try container.decodeIfPresent(String.self, forKey: .postOfficeName)
        label = try container.decode(String.self, forKey: .label)
        ownerUserID = try container.decodeIfPresent(String.self, forKey: .ownerUserID)
        owned = try container.decodeIfPresent(Bool.self, forKey: .owned) ?? true
    }

    var locationLabel: String {
        postOfficeName ?? "Post Office \(postOfficeID)"
    }

    var pickerLabel: String {
        "\(label) · \(locationLabel)"
    }
}
