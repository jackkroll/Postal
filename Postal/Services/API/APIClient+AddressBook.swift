import Foundation

extension APIClient {
    func listAddressBook() async throws -> [AddressBookEntrySummary] {
        let response: AddressBookResponse = try await get(.meAddressbook, authenticated: true)
        return response.entries
    }

    func getAddressBookEntry(id: String) async throws -> AddressBookEntrySummary {
        try await get(.addressEntry(id: id), authenticated: true)
    }

    @discardableResult
    func createAddressBookEntry(
        nickname: String,
        mailboxID: MailboxID,
        notes: String? = nil
    ) async throws -> AddressBookEntrySummary {
        try await post(
            .addAddressToBook,
            body: CreateAddressBookEntryRequest(
                nickname: nickname,
                mailboxID: mailboxID,
                notes: notes
            ),
            authenticated: true
        )
    }

    @discardableResult
    func updateAddressBookEntry(
        id: String,
        nickname: String,
        mailboxID: MailboxID,
        notes: String? = nil
    ) async throws -> AddressBookEntrySummary {
        try await put(
            .updateAddressEntry(id: id),
            body: UpdateAddressBookEntryRequest(
                nickname: nickname,
                mailboxID: mailboxID,
                notes: notes
            ),
            authenticated: true
        )
    }

    func deleteAddressBookEntry(id: String) async throws {
        try await delete(.deleteAddressEntry(id: id), authenticated: true)
    }
}
