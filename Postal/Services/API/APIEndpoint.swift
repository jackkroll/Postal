import Foundation

enum APIEndpoint {
    case health
    case firebaseConfig
    case postOffices(search: String?, limit: Int?)
    case meMailboxes
    case claimMailbox
    case postOfficeMailboxes(postOfficeID: Int)
    case createShipment
    case listShipments(status: ShipmentStatus?, limit: Int?)
    case shipmentDetail(id: String)
    case shipmentEvents(id: String)
    case shipmentLetter(id: String)
    case publicTrack(trackingNumber: String)
    case publicTrackRoute(trackingNumber: String)
    case location(code: Int)

    var path: String {
        switch self {
        case .health:
            return "/health"
        case .firebaseConfig:
            return "/api/firebase-config"
        case .postOffices:
            return "/api/post-offices"
        case .meMailboxes, .claimMailbox:
            return "/api/me/mailboxes"
        case let .postOfficeMailboxes(postOfficeID):
            return "/api/post-offices/\(postOfficeID)/mailboxes"
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
        }
    }

    var method: String {
        switch self {
        case .createShipment, .claimMailbox:
            return "POST"
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
        case let .listShipments(status, limit):
            components.queryItems = queryItems([
                ("status", status?.rawValue),
                ("limit", limit.map(String.init)),
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
