import Foundation

/// Server schedule preset for `POST /api/shipments` (`schedule_preset`).
///
/// Held until **00:00** on the calendar date that is one week / month / year
/// after send time (server-side).
enum SchedulePreset: String, Codable, CaseIterable, Hashable, Sendable {
    case oneWeek = "1_week"
    case oneMonth = "1_month"
    case oneYear = "1_year"

    var displayTitle: String {
        switch self {
        case .oneWeek: "1 week"
        case .oneMonth: "1 month"
        case .oneYear: "1 year"
        }
    }

    /// Local approximation of the hold end (midnight on the target calendar date).
    /// The server is authoritative; use this for client-side validation hints only.
    func deliveryDate(from date: Date = .now, calendar: Calendar = .current) -> Date {
        let offset: DateComponents
        switch self {
        case .oneWeek: offset = DateComponents(day: 7)
        case .oneMonth: offset = DateComponents(month: 1)
        case .oneYear: offset = DateComponents(year: 1)
        }
        let target = calendar.date(byAdding: offset, to: date) ?? date
        return calendar.startOfDay(for: target)
    }
}

/// Nested `scheduling` block from `GET /api/me/entitlements` and `GET /api/me/limits`.
struct SchedulingEntitlements: Codable, Hashable, Sendable {
    var presets: [SchedulePreset]
    var customDeliverAt: Bool
    var routeEstimate: Bool

    enum CodingKeys: String, CodingKey {
        case presets
        case customDeliverAt = "custom_deliver_at"
        case routeEstimate = "route_estimate"
    }

    init(presets: [SchedulePreset], customDeliverAt: Bool, routeEstimate: Bool) {
        self.presets = presets
        self.customDeliverAt = customDeliverAt
        self.routeEstimate = routeEstimate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawPresets = try container.decodeIfPresent([String].self, forKey: .presets) ?? []
        let decoded = rawPresets.compactMap(SchedulePreset.init(rawValue:))
        presets = decoded.isEmpty ? SchedulePreset.allCases : decoded
        customDeliverAt = try container.decodeIfPresent(Bool.self, forKey: .customDeliverAt) ?? false
        routeEstimate = try container.decodeIfPresent(Bool.self, forKey: .routeEstimate) ?? false
    }

    /// Free-tier defaults when the server omits the block (older APIs).
    static let freeDefaults = SchedulingEntitlements(
        presets: SchedulePreset.allCases,
        customDeliverAt: false,
        routeEstimate: false
    )

    static let plusDefaults = SchedulingEntitlements(
        presets: SchedulePreset.allCases,
        customDeliverAt: true,
        routeEstimate: true
    )
}

/// Mutually exclusive schedule options for `POST /api/shipments`.
///
/// Omit entirely for immediate natural delivery.
enum ShipmentSchedule: Hashable, Sendable {
    /// Free + Plus — `schedule_preset`.
    case preset(SchedulePreset)
    /// Plus only — exact `deliver_at` ISO-8601 datetime.
    case deliverAt(Date)
}

/// Response from `GET /api/shipments/estimate` (Plus / `route_estimate` only).
///
/// Does not create a shipment or spend stamps.
struct ShipmentEstimate: Decodable, Hashable, Sendable {
    let originBoxID: MailboxID
    let destinationBoxID: MailboxID
    let originPostOffice: PostOffice?
    let destinationPostOffice: PostOffice?
    let requestedAt: Date?
    let expectedDeliveryTime: Date?
    let routeFound: Bool

    enum CodingKeys: String, CodingKey {
        case originBoxID = "origin_box_id"
        case destinationBoxID = "destination_box_id"
        case originPostOffice = "origin_post_office"
        case destinationPostOffice = "destination_post_office"
        case requestedAt = "requested_at"
        case expectedDeliveryTime = "expected_delivery_time"
        case routeFound = "route_found"
    }
}

extension Date {
    /// ISO-8601 string suitable for `deliver_at` on create / estimate payloads.
    var apiTimestampString: String {
        ISO8601Format()
    }
}
