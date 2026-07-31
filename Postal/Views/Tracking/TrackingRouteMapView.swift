import MapKit
import SwiftUI

struct TrackingRouteMapStop: Identifiable, Hashable {
    enum Kind: Hashable {
        case origin
        case waypoint
        case destination
    }

    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let kind: Kind
    let isCurrent: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func systemImage(for status: ShipmentStatus) -> String {
        switch kind {
        case .origin:
            return ShipmentStatus.awaitingPickup.iconName
        case .waypoint:
            return isCurrent ? status.iconName : ShipmentStatus.atFacility.iconName
        case .destination:
            return status.iconName
        }
    }

    func tint(for status: ShipmentStatus) -> Color {
        switch kind {
        case .origin:
            return ShipmentStatus.awaitingPickup.tintColor
        case .waypoint:
            return isCurrent ? status.tintColor : ShipmentStatus.atFacility.tintColor
        case .destination:
            return status.tintColor
        }
    }
}

struct TrackingRouteMapView: View {
    let route: TrackingRoute
    var isInteractive: Bool = true

    private var stops: [TrackingRouteMapStop] {
        Self.stops(from: route)
    }

    var body: some View {
        Group {
            if stops.isEmpty {
                ContentUnavailableView(
                    "No Map Data",
                    systemImage: "map",
                    description: Text("Facility locations aren’t available for this route yet.")
                )
            } else {
                mapContent
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Route map")
    }

    @ViewBuilder
    private var mapContent: some View {
        let map = Map(initialPosition: .region(Self.region(for: stops))) {
            if stops.count > 1 {
                MapPolyline(coordinates: stops.map(\.coordinate))
                    .stroke(
                        route.statusColor(),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
            }

            ForEach(stops) { stop in
                Marker(
                    stop.name,
                    systemImage: stop.systemImage(for: route.status),
                    coordinate: stop.coordinate
                )
                .tint(stop.tint(for: route.status))
            }
        }
        .mapStyle(.standard)

        if isInteractive {
            map
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapPitchToggle()
                }
        } else {
            map
                .disabled(true)
                .allowsHitTesting(false)
        }
    }

    static func stops(from route: TrackingRoute) -> [TrackingRouteMapStop] {
        var facilitiesByID: [Int: PostOffice] = [:]

        for event in route.events {
            guard let facility = event.facility,
                  facility.lat != nil,
                  facility.lon != nil
            else { continue }
            facilitiesByID[facility.id] = facility
        }

        if let current = route.currentFacility,
           current.lat != nil,
           current.lon != nil {
            facilitiesByID[current.id] = current
        }

        var orderedIDs: [Int] = []
        var seen = Set<Int>()

        for entry in route.timeline {
            guard facilitiesByID[entry.facilityID] != nil, !seen.contains(entry.facilityID) else { continue }
            orderedIDs.append(entry.facilityID)
            seen.insert(entry.facilityID)
        }

        let chronologicalEvents = route.events.sorted {
            eventDate($0) < eventDate($1)
        }
        for event in chronologicalEvents {
            let facilityID = event.facility?.id ?? event.facilityID
            guard let facilityID,
                  facilitiesByID[facilityID] != nil,
                  !seen.contains(facilityID)
            else { continue }
            orderedIDs.append(facilityID)
            seen.insert(facilityID)
        }

        if let currentID = route.currentFacility?.id,
           facilitiesByID[currentID] != nil,
           !seen.contains(currentID) {
            orderedIDs.append(currentID)
        }

        let currentID = route.currentFacility?.id
        let lastIndex = orderedIDs.count - 1

        return orderedIDs.enumerated().compactMap { index, id in
            guard let facility = facilitiesByID[id],
                  let latitude = facility.lat,
                  let longitude = facility.lon
            else { return nil }

            let kind: TrackingRouteMapStop.Kind
            if orderedIDs.count == 1 {
                kind = .destination
            } else if index == 0 {
                kind = .origin
            } else if index == lastIndex {
                kind = .destination
            } else {
                kind = .waypoint
            }

            return TrackingRouteMapStop(
                id: id,
                name: facility.name,
                latitude: latitude,
                longitude: longitude,
                kind: kind,
                isCurrent: currentID == id
            )
        }
    }

    static func region(for stops: [TrackingRouteMapStop]) -> MKCoordinateRegion {
        guard let first = stops.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
            )
        }

        guard stops.count > 1 else {
            return MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }

        let latitudes = stops.map(\.latitude)
        let longitudes = stops.map(\.longitude)
        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.5),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.5)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private static func eventDate(_ event: ShipmentTrackingEvent) -> Date {
        event.recordedAt ?? event.scheduledFor ?? .distantPast
    }
}

struct TrackingRouteMapDetailView: View {
    let route: TrackingRoute

    var body: some View {
        TrackingRouteMapView(route: route, isInteractive: true)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Route")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("In Transit Route Map") {
    TrackingRouteMapView(route: PreviewData.routeInTransit, isInteractive: false)
        .frame(height: 280)
        .padding()
}

#Preview("Full Screen") {
    NavigationStack {
        TrackingRouteMapDetailView(route: PreviewData.routeInTransit)
    }
}

#Preview("Delivered Route Map") {
    TrackingRouteMapView(route: PreviewData.routeDelivered, isInteractive: false)
        .frame(height: 280)
        .padding()
}

#Preview("No Coordinates") {
    TrackingRouteMapView(route: PreviewData.routeNoRouteFound)
        .frame(height: 280)
        .padding()
}
