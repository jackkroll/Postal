import Foundation
import RevenueCat

protocol EntitlementsProviding: AnyObject {
    var entitlements: UserEntitlements? { get }
    func refresh() async
    @discardableResult
    func claimStampAllowance() async throws -> StampAllowanceClaimResponse
    func clear()
}

@Observable
final class EntitlementsService: EntitlementsProviding {
    private(set) var entitlements: UserEntitlements?
    private(set) var lastErrorMessage: String?
    private(set) var isRefreshing = false
    private(set) var isClaimingAllowance = false

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    @MainActor
    func refresh() async {
        isRefreshing = true
        lastErrorMessage = nil
        defer { isRefreshing = false }

        do {
            var next = try await api.getEntitlements()
            // Plus unlimited sends: no numeric STAMP balance needed for gating/UI.
            if !next.unlimitedSends {
                next.stampBalance = await loadStampBalance(
                    fallback: entitlements?.stampBalance ?? 0
                )
            }
            entitlements = next
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    @discardableResult
    func claimStampAllowance() async throws -> StampAllowanceClaimResponse {
        isClaimingAllowance = true
        lastErrorMessage = nil
        defer { isClaimingAllowance = false }

        do {
            let result = try await api.claimStampAllowance()
            // Allowance claim deposits STAMP via the backend → RC; refresh from RC.
            invalidateStampBalanceCache()
            let balance = await loadStampBalance(
                fallback: entitlements?.stampBalance ?? result.stampBalance ?? 0
            )
            if var current = entitlements {
                current.stampBalance = balance
                current.allowance.claimable = false
                current.allowance.nextClaimAt = result.nextClaimAt
                entitlements = current
            } else {
                await refresh()
            }
            return result
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    @MainActor
    func clear() {
        entitlements = nil
        lastErrorMessage = nil
    }

    @MainActor
    func applyLocalMailboxClaim() {
        guard var current = entitlements else { return }
        current.ownedMailboxes += 1
        entitlements = current
    }

    @MainActor
    func applyLocalStampSpend(spent: Int = 1) {
        guard var current = entitlements, !current.unlimitedSends else { return }
        current.stampBalance = max(0, current.stampBalance - spent)
        entitlements = current
        // Backend spends STAMP in RC; drop cache so the next refresh is fresh.
        invalidateStampBalanceCache()
    }

    func invalidateStampBalanceCache() {
        Purchases.shared.invalidateVirtualCurrenciesCache()
    }

    /// STAMP balance from RevenueCat; uses `fallback` if the RC request fails.
    private func loadStampBalance(fallback: Int) async -> Int {
        do {
            return try await Self.fetchStampBalance()
        } catch {
            lastErrorMessage = error.localizedDescription
            return fallback
        }
    }

    private static func fetchStampBalance() async throws -> Int {
        let currencies = try await Purchases.shared.virtualCurrencies()
        return currencies[AppConfiguration.stampVirtualCurrencyCode]?.balance ?? 0
    }
}
