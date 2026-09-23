import Foundation

/// Shared block list, so the address book, composer, and settings all agree on
/// who is blocked without each refetching `GET /api/me/blocks`.
@Observable
final class BlockService {
    private(set) var blocks: [BlockedAddress] = []
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var loadFailure: PostalLoadFailure?

    private let api: APIClient
    private let entitlements: EntitlementsProviding

    init(api: APIClient, entitlements: EntitlementsProviding = AppServices.entitlements) {
        self.api = api
        self.entitlements = entitlements
    }

    /// The block covering `mailboxID`, if that exact address is the one on record.
    /// A person blocked through one of their other mailboxes has no match here.
    func block(for mailboxID: MailboxID) -> BlockedAddress? {
        blocks.first { $0.matches(mailboxID) }
    }

    func isBlocked(_ mailboxID: MailboxID) -> Bool {
        block(for: mailboxID) != nil
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            blocks = try await api.listBlocks()
            loadFailure = nil
            hasLoaded = true
        } catch {
            guard !error.isPostalCancellation else { return }
            loadFailure = error.postalLoadFailure
        }
    }

    /// Blocks the owner of `mailboxID` and reconciles the mail it just failed.
    @MainActor
    @discardableResult
    func block(mailboxID: MailboxID) async throws -> BlockedAddress {
        let created = try await api.createBlock(mailboxID: mailboxID.rawValue)
        apply(created)

        if let cancelled = created.cancelledLetters, cancelled > 0 {
            await reconcileCancelledLetters()
        }

        return created
    }

    @MainActor
    func unblock(id: String) async throws {
        do {
            try await api.deleteBlock(id: id)
        } catch {
            // 404 means the block is already gone; the local list is what's stale.
            guard (error as? APIError)?.httpStatusCode == 404 else { throw error }
        }
        blocks.removeAll { $0.id == id }
    }

    @MainActor
    func clear() {
        blocks = []
        hasLoaded = false
        loadFailure = nil
    }

    /// Adopts a list fetched elsewhere (previews, or a caller that already has a
    /// fresher server response) without another round trip.
    func replaceAll(_ blocks: [BlockedAddress]) {
        self.blocks = blocks
        hasLoaded = true
        loadFailure = nil
    }

    /// Re-blocking returns the existing record, so match on id rather than appending.
    @MainActor
    private func apply(_ block: BlockedAddress) {
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
        } else {
            blocks.append(block)
        }
    }

    /// Cancelled letters are now `failed` server-side, and each one refunded its
    /// sender — which may include this user.
    @MainActor
    private func reconcileCancelledLetters() async {
        NotificationCenter.default.post(name: .postalLettersDidChangeRemotely, object: nil)

        if let service = entitlements as? EntitlementsService {
            service.invalidateStampBalanceCache()
        }
        await entitlements.refresh()
    }
}

extension BlockService {
    static func blockFailureMessage(_ error: Error) -> String {
        if case let .httpStatus(400, message, _)? = error as? APIError {
            // The self-block rejection is the one server string written for users.
            if let message, message.localizedCaseInsensitiveContains("own mailbox") {
                return message
            }
            return BlockText.unknownMailbox
        }
        return connectivityMessage(error) ?? BlockText.blockFailed
    }

    static func unblockFailureMessage(_ error: Error) -> String {
        connectivityMessage(error) ?? BlockText.unblockFailed
    }

    /// Offline / server-down wording is worth surfacing; everything else gets
    /// action-specific copy instead of a raw `detail`.
    private static func connectivityMessage(_ error: Error) -> String? {
        let failure = error.postalLoadFailure
        return failure.kind == .other ? nil : failure.message
    }
}
