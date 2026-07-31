import Foundation

/// Inbound URLs that should open a specific screen in Postal.
enum DeepLink: Equatable, Sendable {
    case track(trackingNumber: String)

    /// Shareable / public tracking URL: `https://postal.jackk.dev/track/{number}`.
    static func trackURL(for trackingNumber: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = AppConfiguration.deepLinkHost
        components.path = "/track/\(trackingNumber)"
        return components.url!
    }

    static func parse(_ url: URL) -> DeepLink? {
        if let scheme = url.scheme?.lowercased(), scheme == AppConfiguration.urlScheme {
            return parseCustomScheme(url)
        }

        guard let host = url.host?.lowercased(),
              AppConfiguration.deepLinkHosts.contains(host) else {
            return nil
        }
        return parseTrackPath(url.pathComponents)
    }

    // MARK: - Private

    /// `postal://track/{number}` or `postal:///track/{number}`.
    private static func parseCustomScheme(_ url: URL) -> DeepLink? {
        if url.host?.lowercased() == "track" {
            let number = url.pathComponents.first(where: { $0 != "/" })
            return trackingDeepLink(from: number)
        }
        return parseTrackPath(url.pathComponents)
    }

    /// `/track/{number}` and `/track/{number}/route`.
    private static func parseTrackPath(_ components: [String]) -> DeepLink? {
        let parts = components.filter { $0 != "/" }
        guard parts.count >= 2, parts[0].lowercased() == "track" else { return nil }
        return trackingDeepLink(from: parts[1])
    }

    private static func trackingDeepLink(from raw: String?) -> DeepLink? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return .track(trackingNumber: trimmed)
    }
}
