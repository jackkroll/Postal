import Foundation

/// Response from `GET /invite/{mailbox_id}`.
struct MailboxInvite: Codable, Hashable, Identifiable {
    let mailboxID: MailboxID
    let label: String
    let postOffice: PostOffice
    let invitePath: String

    var id: MailboxID { mailboxID }

    var mailboxSummary: MailboxSummary {
        MailboxSummary(
            id: mailboxID,
            postOfficeID: postOffice.id,
            postOfficeName: postOffice.name,
            label: label,
            ownerUserID: nil,
            owned: false
        )
    }

    /// Prefer the server-provided path when it is absolute or host-relative.
    var shareURL: URL {
        DeepLink.inviteURL(fromInvitePath: invitePath) ?? DeepLink.inviteURL(for: mailboxID)
    }

    init(mailboxID: MailboxID, label: String, postOffice: PostOffice, invitePath: String) {
        self.mailboxID = mailboxID
        self.label = label
        self.postOffice = postOffice
        self.invitePath = invitePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mailboxID = try Self.decode(MailboxID.self, from: container, keys: [.mailboxID, .mailboxId])
        label = try container.decode(String.self, forKey: .label)
        postOffice = try Self.decode(PostOffice.self, from: container, keys: [.postOffice, .postOfficeCamel])
        invitePath = try Self.decode(String.self, from: container, keys: [.invitePath, .invitePathCamel])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mailboxID, forKey: .mailboxID)
        try container.encode(label, forKey: .label)
        try container.encode(postOffice, forKey: .postOffice)
        try container.encode(invitePath, forKey: .invitePath)
    }

    private enum CodingKeys: String, CodingKey {
        case mailboxID = "mailbox_id"
        case mailboxId
        case label
        case postOffice = "post_office"
        case postOfficeCamel = "postOffice"
        case invitePath = "invite_path"
        case invitePathCamel = "invitePath"
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) throws -> T {
        var lastError: Error?
        for key in keys {
            do {
                return try container.decode(T.self, forKey: key)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? DecodingError.keyNotFound(
            keys[0],
            .init(codingPath: container.codingPath, debugDescription: "Missing invite field.")
        )
    }
}
