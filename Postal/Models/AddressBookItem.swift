import Foundation

/// Response from `GET /api/me/addressbook`.
struct AddressBookResponse: Codable, Hashable {
    let entries: [AddressBookEntrySummary]
}

/// Body for `POST /api/me/addressbook`.
struct CreateAddressBookEntryRequest: Codable, Hashable {
    let nickname: String
    let mailboxID: MailboxID
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case mailboxID = "mailbox_id"
        case notes
    }

    init(nickname: String, mailboxID: MailboxID, notes: String? = nil) {
        self.nickname = nickname
        self.mailboxID = mailboxID
        self.notes = notes
    }
}

/// Body for `PUT /api/me/addressbook/{entry_id}`.
struct UpdateAddressBookEntryRequest: Codable, Hashable {
    let nickname: String
    let mailboxID: MailboxID
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case mailboxID = "mailbox_id"
        case notes
    }

    init(nickname: String, mailboxID: MailboxID, notes: String? = nil) {
        self.nickname = nickname
        self.mailboxID = mailboxID
        self.notes = notes
    }
}

/// Response item from address-book list/create/get/update endpoints.
struct AddressBookEntrySummary: Codable, Hashable, Identifiable {
    let id: String
    let nickname: String
    let mailboxID: MailboxID
    let notes: String?
    let postOfficeID: Int?
    let postOfficeName: String?
    let mailboxLabel: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case mailboxID = "mailbox_id"
        case notes
        case postOfficeID = "post_office_id"
        case postOfficeName = "post_office_name"
        case mailboxLabel = "mailbox_label"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var mailboxSummary: MailboxSummary {
        MailboxSummary(
            id: mailboxID,
            postOfficeID: postOfficeID ?? mailboxID.postOfficeID,
            postOfficeName: postOfficeName,
            label: mailboxLabel ?? "Box \(mailboxID.code)",
            ownerUserID: nil,
            owned: false
        )
    }
}
