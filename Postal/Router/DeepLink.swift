import Foundation

/// Inbound URLs that should open a specific screen in Postal.
enum DeepLink: Equatable, Sendable {
    case track(trackingNumber: String)
    case invite(mailboxID: MailboxID)

    /// Shareable / public tracking URL: `https://postal.jackk.dev/track/{number}`.
    static func trackURL(for trackingNumber: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = AppConfiguration.deepLinkHost
        components.path = "/track/\(trackingNumber)"
        return components.url!
    }

    /// Shareable mailbox invite URL: `https://postal.jackk.dev/invite/{postOfficeID}:{code}`.
    static func inviteURL(for mailboxID: MailboxID) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = AppConfiguration.deepLinkHost
        components.percentEncodedPath = "/invite/\(percentEncodedMailboxID(mailboxID.rawValue))"
        return components.url!
    }

    /// Builds a share URL from the server's `invite_path` (absolute or `/invite/...`).
    static func inviteURL(fromInvitePath path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let absolute = URL(string: trimmed), absolute.scheme != nil, absolute.host != nil {
            return absolute
        }

        let normalized = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        if let mailboxID = mailboxID(fromInvitePathComponents: normalized.split(separator: "/").map(String.init)) {
            return inviteURL(for: mailboxID)
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = AppConfiguration.deepLinkHost
        components.percentEncodedPath = percentEncodedInvitePath(normalized)
        return components.url
    }

    static func parse(_ url: URL) -> DeepLink? {
        if let scheme = url.scheme?.lowercased(), scheme == AppConfiguration.urlScheme {
            return parseCustomScheme(url)
        }

        guard let host = url.host?.lowercased(),
              AppConfiguration.deepLinkHosts.contains(host) else {
            return nil
        }
        return parsePath(url.pathComponents)
    }

    /// Parses an invite from a QR payload (URL, path, or raw mailbox id).
    static func mailboxID(fromInvitePayload payload: String) -> MailboxID? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let link = parse(url), case let .invite(id) = link {
            return id
        }
        if let id = MailboxID(rawValue: trimmed) {
            return id
        }
        // Path without scheme, e.g. `invite/42:ABC` or `/invite/42%3AABC`.
        let parts = trimmed
            .split(whereSeparator: { $0 == "/" || $0 == "?" })
            .map(String.init)
            .filter { !$0.isEmpty }
        if let idx = parts.firstIndex(where: { $0.lowercased() == "invite" }),
           idx + 1 < parts.count {
            let raw = parts[idx + 1].removingPercentEncoding ?? parts[idx + 1]
            return MailboxID(rawValue: raw)
        }
        return nil
    }

    // MARK: - Private

    /// `postal://track/{number}`, `postal://invite/{mailboxID}`, or `postal:///…`.
    private static func parseCustomScheme(_ url: URL) -> DeepLink? {
        if let host = url.host?.lowercased() {
            switch host {
            case "track":
                let number = url.pathComponents.first(where: { $0 != "/" })
                return trackingDeepLink(from: number)
            case "invite":
                let raw = url.pathComponents.first(where: { $0 != "/" })
                return inviteDeepLink(from: raw)
            default:
                break
            }
        }
        return parsePath(url.pathComponents)
    }

    private static func parsePath(_ components: [String]) -> DeepLink? {
        let parts = components.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }

        switch parts[0].lowercased() {
        case "track":
            return trackingDeepLink(from: parts[1])
        case "invite":
            return inviteDeepLink(from: parts[1])
        default:
            return nil
        }
    }

    private static func trackingDeepLink(from raw: String?) -> DeepLink? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return .track(trackingNumber: trimmed)
    }

    private static func inviteDeepLink(from raw: String?) -> DeepLink? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .removingPercentEncoding ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mailboxID = MailboxID(rawValue: trimmed) else { return nil }
        return .invite(mailboxID: mailboxID)
    }

    private static func mailboxID(fromInvitePathComponents parts: [String]) -> MailboxID? {
        let filtered = parts.filter { !$0.isEmpty && $0 != "/" }
        guard filtered.count >= 2, filtered[0].lowercased() == "invite" else { return nil }
        let raw = filtered[1].removingPercentEncoding ?? filtered[1]
        return MailboxID(rawValue: raw)
    }

    private static func percentEncodedMailboxID(_ raw: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: ":/?#[]@!$&'()*+,;=")
        return raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? raw
    }

    private static func percentEncodedInvitePath(_ path: String) -> String {
        path
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { segment -> String in
                if segment.isEmpty { return "" }
                return percentEncodedMailboxID(String(segment))
            }
            .joined(separator: "/")
    }
}
