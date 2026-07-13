import Foundation

extension APIClient {
    func listOwnedMailboxes() async throws -> [MailboxSummary] {
        try await get(.meMailboxes, authenticated: true)
    }

    func listPostOffices(search: String? = nil, limit: Int? = nil) async throws -> [PostOffice] {
        try await get(.postOffices(search: search, limit: limit), authenticated: true)
    }

    func listMailboxes(postOfficeID: Int) async throws -> [MailboxSummary] {
        try await get(.postOfficeMailboxes(postOfficeID: postOfficeID), authenticated: true)
    }

    func lookupMailbox(postOfficeID: Int, code: String) async throws -> MailboxSummary {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else {
            throw MailboxLookupError.notFound(code: code)
        }

        let mailboxID = "\(postOfficeID):\(normalizedCode)"
        let mailboxes = try await listMailboxes(postOfficeID: postOfficeID)
        guard let mailbox = mailboxes.first(where: {
            $0.id.caseInsensitiveCompare(mailboxID) == .orderedSame
        }) else {
            throw MailboxLookupError.notFound(code: normalizedCode)
        }
        return mailbox
    }
}
