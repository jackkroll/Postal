import Foundation

protocol InboundLetterOpenStoring: AnyObject {
    func hasOpened(_ shipmentID: String) -> Bool
    func markOpened(_ shipmentID: String)
    func prune(keeping shipmentIDs: Set<String>)
}

/// Tracks which inbound shipments the user has opened (tracking as recipient).
/// Persists only shipment ID strings in UserDefaults.
final class InboundLetterOpenStore: InboundLetterOpenStoring {
    static let shared = InboundLetterOpenStore()

    /// Grace period before never-opened terminal inbound mail moves to Completed.
    static let archiveGraceInterval: TimeInterval = 14 * 24 * 60 * 60

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        key: String = AppStorageKeys.openedInboundShipmentIDs
    ) {
        self.defaults = defaults
        self.key = key
    }

    func hasOpened(_ shipmentID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return loadIDsUnlocked().contains(shipmentID)
    }

    func markOpened(_ shipmentID: String) {
        let trimmed = shipmentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        var ids = loadIDsUnlocked()
        guard ids.insert(trimmed).inserted else { return }
        defaults.set(Array(ids), forKey: key)
    }

    func prune(keeping shipmentIDs: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        let current = loadIDsUnlocked()
        let pruned = current.intersection(shipmentIDs)
        guard pruned != current else { return }
        defaults.set(Array(pruned), forKey: key)
    }

    private func loadIDsUnlocked() -> Set<String> {
        let stored = defaults.stringArray(forKey: key) ?? []
        return Set(stored)
    }

    /// Terminal inbound mail archives after open, or after the grace window.
    static func isArchived(_ letter: LetterSummary, openStore: InboundLetterOpenStoring) -> Bool {
        guard letter.status.isTerminal else { return false }
        if openStore.hasOpened(letter.shipmentID) { return true }
        let anchor = letter.updatedAt ?? letter.createdAt ?? .distantPast
        return anchor < Date().addingTimeInterval(-archiveGraceInterval)
    }
}
