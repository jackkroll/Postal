import Foundation

enum APIEndpoint {
    case health
    case firebaseConfig
    case postOffices(search: String?, limit: Int?)
    case deleteMyAccount
    case meMailboxes
    case claimMailbox
    case meDeviceTokens
    case registerDeviceToken
    case unregisterDeviceToken
    case meNotificationPreferences
    case updateNotificationPreferences
    case meInboundLetters(status: ShipmentStatus?, limit: Int?)
    case meMailboxInboundLetters(mailboxID: String, status: ShipmentStatus?, limit: Int?)
    case validateMailbox(mailboxID: String)
    case validatePostOffice(postOfficeID: Int)
    case createShipment
    case listShipments(status: ShipmentStatus?, limit: Int?)
    case shipmentDetail(id: String)
    case shipmentEvents(id: String)
    case shipmentLetter(id: String)
    case publicTrack(trackingNumber: String)
    case publicTrackRoute(trackingNumber: String)
    case location(code: Int)
    case meAddressbook
    case addAddressToBook
    case addressEntry(id: String)
    case updateAddressEntry(id: String)
    case deleteAddressEntry(id: String)

    var path: String {
        switch self {
        case .health:
            return "/health"
        case .firebaseConfig:
            return "/api/firebase-config"
        case .postOffices:
            return "/api/post-offices"
        case .deleteMyAccount:
            return "/api/me"
        case .meMailboxes, .claimMailbox:
            return "/api/me/mailboxes"
        case .meDeviceTokens, .registerDeviceToken, .unregisterDeviceToken:
            return "/api/me/device-tokens"
        case .meNotificationPreferences, .updateNotificationPreferences:
            return "/api/me/notification-preferences"
        case .meInboundLetters:
            return "/api/me/inbound-letters"
        case let .meMailboxInboundLetters(mailboxID, _, _):
            return "/api/me/mailboxes/\(mailboxID)/inbound-letters"
        case .validateMailbox:
            return "/api/mailboxes/validate"
        case let .validatePostOffice(postOfficeID):
            return "/api/post-offices/\(postOfficeID)/validate"
        case .createShipment:
            return "/api/shipments"
        case .listShipments:
            return "/api/shipments"
        case let .shipmentDetail(id):
            return "/api/shipments/\(id)"
        case let .shipmentEvents(id):
            return "/api/shipments/\(id)/events"
        case let .shipmentLetter(id):
            return "/api/shipments/\(id)/letter"
        case let .publicTrack(trackingNumber):
            return "/track/\(trackingNumber)"
        case let .publicTrackRoute(trackingNumber):
            return "/track/\(trackingNumber)/route"
        case let .location(code):
            return "/api/locations/\(code)"
        case .meAddressbook, .addAddressToBook:
            return "/api/me/addressbook"
        case let .addressEntry(id), let .updateAddressEntry(id), let .deleteAddressEntry(id):
            return "/api/me/addressbook/\(id)"
        }
    }

    var method: String {
        switch self {
        case .createShipment, .claimMailbox, .registerDeviceToken, .addAddressToBook:
            return "POST"
        case .updateNotificationPreferences, .updateAddressEntry:
            return "PUT"
        case .unregisterDeviceToken, .deleteMyAccount, .deleteAddressEntry:
            return "DELETE"
        case .shipmentLetter:
            return "GET"
        default:
            return "GET"
        }
    }

    var supportsHEAD: Bool {
        switch self {
        case .shipmentLetter:
            return true
        default:
            return false
        }
    }

    func url(baseURL: URL) -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            return baseURL.appendingPathComponent(path)
        }

        switch self {
        case let .postOffices(search, limit):
            components.queryItems = queryItems([
                ("search", search),
                ("limit", limit.map(String.init)),
            ])
        case let .listShipments(status, limit),
             let .meInboundLetters(status, limit),
             let .meMailboxInboundLetters(_, status, limit):
            components.queryItems = queryItems([
                ("status", status?.rawValue),
                ("limit", limit.map(String.init)),
            ])
        case let .validateMailbox(mailboxID):
            components.queryItems = queryItems([
                ("mailbox_id", mailboxID),
            ])
        default:
            break
        }

        return components.url ?? baseURL.appendingPathComponent(path)
    }

    private func queryItems(_ pairs: [(String, String?)]) -> [URLQueryItem] {
        pairs.compactMap { name, value in
            guard let value, !value.isEmpty else { return nil }
            return URLQueryItem(name: name, value: value)
        }
    }
}

