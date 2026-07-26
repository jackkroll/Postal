import Foundation

protocol LetterLimitsProviding: AnyObject {
    var limits: LetterLimits { get }
    func refresh() async
    func clear()
}

/// Serves letter size ceilings to the compose flow from `GET /api/me/limits`.
///
/// Falls back to `AppConfiguration.letterLimits` until a successful fetch, and
/// again after sign-out via `clear()`.
@Observable
final class LetterLimitsService: LetterLimitsProviding {
    private(set) var limits: LetterLimits
    private(set) var lastErrorMessage: String?
    private(set) var isRefreshing = false

    private let api: APIClient
    private let fallback: LetterLimits

    init(
        api: APIClient,
        fallback: LetterLimits = AppConfiguration.letterLimits
    ) {
        self.api = api
        self.fallback = fallback
        self.limits = fallback
    }

    @MainActor
    func refresh() async {
        isRefreshing = true
        lastErrorMessage = nil
        defer { isRefreshing = false }

        do {
            limits = try await api.getLimits()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func clear() {
        limits = fallback
        lastErrorMessage = nil
    }
}
