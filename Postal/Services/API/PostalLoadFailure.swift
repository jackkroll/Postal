import Foundation

/// Classifies load failures so the UI can say whether the device is offline
/// or the Postal server specifically looks unreachable.
struct PostalLoadFailure: Equatable {
    enum Kind: Equatable {
        /// Device has no usable network path.
        case offline
        /// Network seems up, but the API host/server did not respond successfully.
        case serverUnreachable
        /// Auth, validation, decoding, or other non-connectivity failures.
        case other
    }

    let kind: Kind
    let message: String

    init(error: Error) {
        if error.isPostalCancellation {
            kind = .other
            message = error.localizedDescription
            return
        }

        if let urlError = Self.urlError(from: error) {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                kind = .offline
                message = "Your device appears to be offline. Check your internet connection and try again."
                return
            case .timedOut:
                kind = .serverUnreachable
                message = "The server took too long to respond. It may be down, or your connection may be unstable."
                return
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .secureConnectionFailed,
                 .badServerResponse:
                kind = .serverUnreachable
                message = "Couldn't reach the Postal server. The server may be down. Try again soon."
                return
            case .cancelled:
                kind = .other
                message = error.localizedDescription
                return
            default:
                break
            }
        }

        if let apiError = error as? APIError {
            switch apiError {
            case let .httpStatus(code, _, _) where [502, 503, 504].contains(code):
                kind = .serverUnreachable
                message = "The Postal server is temporarily unavailable. Try again in a few minutes."
                return
            case .invalidResponse:
                kind = .serverUnreachable
                message = "The Postal server returned an unexpected response."
                return
            default:
                break
            }
        }

        kind = .other
        message = error.localizedDescription
    }

    func title(resource: String) -> String {
        switch kind {
        case .offline:
            return "You're Offline"
        case .serverUnreachable:
            return "Server Unavailable"
        case .other:
            return "Couldn't Load \(resource)"
        }
    }

    var systemImage: String {
        switch kind {
        case .offline:
            return "wifi.slash"
        case .serverUnreachable:
            return "server.rack"
        case .other:
            return "exclamationmark.triangle"
        }
    }

    private static func urlError(from error: Error) -> URLError? {
        if let urlError = error as? URLError {
            return urlError
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return URLError(URLError.Code(rawValue: nsError.code))
        }
        var current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        while let underlying = current {
            if underlying.domain == NSURLErrorDomain {
                return URLError(URLError.Code(rawValue: underlying.code))
            }
            current = underlying.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return nil
    }
}

extension Error {
    var isPostalCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    var postalLoadFailure: PostalLoadFailure {
        PostalLoadFailure(error: self)
    }
}
