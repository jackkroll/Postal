import Foundation

protocol LetterLimitsProviding: AnyObject {
    var limits: LetterLimits { get }
    func refresh() async
}

/// Serves letter size ceilings to the compose flow.
///
/// Values come from `AppConfiguration` today; `refresh()` is the seam where a
/// `GET /letters/limits` response will replace them once the endpoint exists.
@Observable
final class LetterLimitsService: LetterLimitsProviding {
    private(set) var limits: LetterLimits

    init(limits: LetterLimits = AppConfiguration.letterLimits) {
        self.limits = limits
    }

    @MainActor
    func refresh() async {}
}
