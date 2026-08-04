import Foundation
import SwiftUI

struct RouteTimelineEntry: Codable, Hashable, Identifiable {
    let facilityID: Int
    let tier: Int?
    let arrival: Date?
    let departure: Date?

    var id: Int { facilityID }

    enum CodingKeys: String, CodingKey {
        case facilityID = "facility_id"
        case tier
        case arrival
        case departure
    }
}

struct ShipmentTrackingEvent: Codable, Hashable, Identifiable {
    /// Server event id from `/track/{id}/route` (`id`).
    let eventID: Int?
    let eventType: String
    let facility: PostOffice?
    let facilityID: Int?
    let scheduledFor: Date?
    let recordedAt: Date?

    var id: String {
        if let eventID {
            return String(eventID)
        }
        return "\(eventType)-\(scheduledFor?.timeIntervalSince1970 ?? 0)-\(facility?.id ?? facilityID ?? 0)"
    }

    enum CodingKeys: String, CodingKey {
        case eventID = "id"
        case eventType = "event_type"
        case facility
        case facilityID = "facility_id"
        case scheduledFor = "scheduled_for"
        case recordedAt = "recorded_at"
    }

    init(
        eventID: Int? = nil,
        eventType: String,
        facility: PostOffice?,
        facilityID: Int?,
        scheduledFor: Date?,
        recordedAt: Date?
    ) {
        self.eventID = eventID
        self.eventType = eventType
        self.facility = facility
        self.facilityID = facilityID
        self.scheduledFor = scheduledFor
        self.recordedAt = recordedAt
    }
}

struct TrackingRoute: Codable, Hashable {
    let trackingNumber: String
    let status: ShipmentStatus
    let routeFound: Bool
    let currentFacility: PostOffice?
    let timeline: [RouteTimelineEntry]
    let events: [ShipmentTrackingEvent]

    enum CodingKeys: String, CodingKey {
        case trackingNumber = "tracking_number"
        case status
        case routeFound = "route_found"
        case currentFacility = "current_facility"
        case timeline
        case events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackingNumber = try container.decode(String.self, forKey: .trackingNumber)
        status = try container.decode(ShipmentStatus.self, forKey: .status)
        routeFound = try container.decodeIfPresent(Bool.self, forKey: .routeFound) ?? false
        currentFacility = try container.decodeIfPresent(PostOffice.self, forKey: .currentFacility)
        timeline = try container.decodeIfPresent([RouteTimelineEntry].self, forKey: .timeline) ?? []
        events = try container.decodeIfPresent([ShipmentTrackingEvent].self, forKey: .events) ?? []
    }
    
    func statusColor() -> Color {
        status.tintColor
    }

    func statusIcon() -> String {
        status.iconName
    }

    func statusSummary() -> TrackingStatusSummary {
        let title = status.displayTitle
        let facilityName = currentFacility?.name ?? latestEvent?.facility?.name
        let latestDate = latestEventDate
        let relativeTime = latestDate.map(formatRelativeTime)
        let stopsVisited = timeline.filter { $0.arrival != nil }.count

        switch status {
        case .awaitingPickup:
            return TrackingStatusSummary(
                title: title,
                message: "Your letter is waiting to be picked up.",
                context: joinContext([
                    facilityName.map { "Held at \($0)" },
                    relativeTime.map { "Created \($0)" },
                ])
            )

        case .inTransit:
            let message = stopsVisited > 1
                ? "Your letter is moving through the network."
                : "Your letter is on its way."

            var contextParts: [String?] = []
            if let facilityName {
                if latestEvent?.eventType == "departed" || latestEvent?.eventType == "departed_facility" {
                    contextParts.append("Left \(facilityName)")
                } else {
                    contextParts.append("Last scanned at \(facilityName)")
                }
            }
            contextParts.append(relativeTime.map { "Updated \($0)" })
            if stopsVisited > 0 {
                let stopLabel = stopsVisited == 1 ? "1 stop" : "\(stopsVisited) stops"
                contextParts.append("\(stopLabel) so far")
            }

            return TrackingStatusSummary(
                title: title,
                message: message,
                context: joinContext(contextParts)
            )

        case .atFacility:
            let arrivalTime = activeTimelineEntry?.arrival ?? latestDate
            return TrackingStatusSummary(
                title: title,
                message: "Your letter is being processed",
                context: joinContext([
                    facilityName.map { "At \($0)" },
                    arrivalTime.map { "Arrived \(formatRelativeTime($0))" },
                ])
            )

        case .outForDelivery:
            return TrackingStatusSummary(
                title: title,
                message: "Your letter is on its final delivery run.",
                context: joinContext([
                    facilityName.map { "Dispatched from \($0)" },
                    relativeTime.map { "Updated \($0)" },
                ])
            )

        case .delivered:
            let deliveredEvent = events.last { $0.eventType == "delivered" } ?? latestEvent
            let deliveredFacility = deliveredEvent?.facility?.name ?? facilityName
            let deliveredDate = deliveredEvent?.recordedAt
                ?? deliveredEvent.map { eventDate($0) }.flatMap { $0 == .distantPast ? nil : $0 }

            return TrackingStatusSummary(
                title: title,
                message: "Your letter has been delivered.",
                context: joinContext([
                    deliveredFacility.map { "To \($0)" },
                    deliveredDate.map { formatAbsoluteTime($0) },
                ])
            )

        case .failed:
            return TrackingStatusSummary(
                title: title,
                message: routeFound
                    ? "This shipment could not be completed."
                    : "We couldn't find tracking details for this number.",
                context: joinContext([
                    facilityName.map { "Last known location: \($0)" },
                    relativeTime.map { "Last update \($0)" },
                ])
            )
        }
    }

    private var latestEvent: ShipmentTrackingEvent? {
        events.max(by: { eventDate($0) < eventDate($1) })
    }

    private var latestEventDate: Date? {
        guard let latestEvent else { return nil }
        let date = eventDate(latestEvent)
        return date == .distantPast ? nil : date
    }

    private var activeTimelineEntry: RouteTimelineEntry? {
        timeline.last { $0.departure == nil }
    }

    private func eventDate(_ event: ShipmentTrackingEvent) -> Date {
        event.recordedAt ?? event.scheduledFor ?? .distantPast
    }

    private func formatRelativeTime(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .wide))
    }

    private func formatAbsoluteTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func joinContext(_ parts: [String?]) -> String? {
        let joined = parts.compactMap { $0 }.filter { !$0.isEmpty }
        return joined.isEmpty ? nil : joined.joined(separator: " · ")
    }
}

struct TrackingStatusSummary {
    let title: String
    let message: String
    let context: String?
}

extension TrackingRoute {
    /// Actual delivery time from the `delivered` scan event, when present.
    var deliveredAt: Date? {
        events.last { $0.eventType == "delivered" }?.recordedAt
    }
}
