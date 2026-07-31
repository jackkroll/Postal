import Foundation

protocol LetterLimitsProviding: AnyObject {
    var limits: LetterLimits? { get }
    func refresh() async
    func clear()
}

/// Serves letter size ceilings to the compose flow from `GET /api/me/limits`.
@Observable
final class LetterLimitsService: LetterLimitsProviding {
    private(set) var limits: LetterLimits?
    private(set) var lastErrorMessage: String?
    private(set) var isRefreshing = false

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
        self.limits = nil
    }

    @MainActor
    func refresh() async {
        isRefreshing = true
        lastErrorMessage = nil
        defer { isRefreshing = false }

        do {
            limits = try await api.getLimits()
        } catch {
            limits = nil
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func clear() {
        limits = nil
        lastErrorMessage = nil
    }
}
