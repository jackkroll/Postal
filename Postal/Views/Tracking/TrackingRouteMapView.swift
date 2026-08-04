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
    /// Coordinates from `GET /api/locations/{code}` — live `/route` facilities are id/name only.
    var locationsByCode: [Int: Location] = [:]
    var trackingInfo: TrackingInfo? = nil
    var isInteractive: Bool = true
    /// Wait for MapKit warmup before mounting `Map` so the first paint isn’t a cold hitch.
    var waitsForWarmup: Bool = true

    @State private var isMapReady = false

    private var stops: [TrackingRouteMapStop] {
        Self.stops(from: route, locationsByCode: locationsByCode, trackingInfo: trackingInfo)
    }

    var body: some View {
        Group {
            if stops.isEmpty {
                ContentUnavailableView(
                    "No Map Data",
                    systemImage: "map",
                    description: Text("Facility locations aren’t available for this route yet.")
                )
            } else if isMapReady || !waitsForWarmup {
                mapContent
            } else {
                mapPlaceholder
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Route map")
        .task(id: "\(route.trackingNumber)-\(waitsForWarmup)") {
            guard waitsForWarmup else {
                isMapReady = true
                return
            }
            isMapReady = false
            await MapKitWarmup.prepare()
            guard !Task.isCancelled else { return }
            await Task.yield()
            isMapReady = true
        }
    }

    private var mapPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(route.statusColor().opacity(0.12))
            ProgressView()
                .tint(route.statusColor())
        }
        .accessibilityLabel("Loading map")
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

    /// Facility IDs that need coordinate lookup for the map.
    static func facilityIDs(in route: TrackingRoute, trackingInfo: TrackingInfo? = nil) -> Set<Int> {
        var ids = Set<Int>()
        for event in route.events {
            if let id = event.facility?.id ?? event.facilityID {
                ids.insert(id)
            }
        }
        if let currentID = route.currentFacility?.id {
            ids.insert(currentID)
        }
        for entry in route.timeline {
            ids.insert(entry.facilityID)
        }
        if let trackingInfo {
            ids.insert(trackingInfo.fromPostOffice.id)
            ids.insert(trackingInfo.toPostOffice.id)
        }
        return ids
    }

    static func stops(
        from route: TrackingRoute,
        locationsByCode: [Int: Location] = [:],
        trackingInfo: TrackingInfo? = nil
    ) -> [TrackingRouteMapStop] {
        var namesByID: [Int: String] = [:]
        var coordinatesByID: [Int: (lat: Double, lon: Double)] = [:]

        func ingest(_ facility: PostOffice) {
            namesByID[facility.id] = facility.name
            if let lat = facility.lat, let lon = facility.lon {
                coordinatesByID[facility.id] = (lat, lon)
            }
        }

        for event in route.events {
            if let facility = event.facility {
                ingest(facility)
            }
        }
        if let current = route.currentFacility {
            ingest(current)
        }
        if let trackingInfo {
            ingest(trackingInfo.fromPostOffice)
            ingest(trackingInfo.toPostOffice)
        }

        for (code, location) in locationsByCode {
            if namesByID[code] == nil {
                namesByID[code] = location.name
            }
            coordinatesByID[code] = (location.latitude, location.longitude)
        }

        var orderedIDs: [Int] = []
        var seen = Set<Int>()

        func appendIfMappable(_ id: Int) {
            guard coordinatesByID[id] != nil, !seen.contains(id) else { return }
            orderedIDs.append(id)
            seen.insert(id)
        }

        for entry in route.timeline {
            appendIfMappable(entry.facilityID)
        }

        let chronologicalEvents = route.events.sorted {
            eventDate($0) < eventDate($1)
        }
        for event in chronologicalEvents {
            if let facilityID = event.facility?.id ?? event.facilityID {
                appendIfMappable(facilityID)
            }
        }

        if let currentID = route.currentFacility?.id {
            appendIfMappable(currentID)
        }

        if let trackingInfo {
            let fromID = trackingInfo.fromPostOffice.id
            if coordinatesByID[fromID] != nil, !seen.contains(fromID) {
                orderedIDs.insert(fromID, at: 0)
                seen.insert(fromID)
            }
            let toID = trackingInfo.toPostOffice.id
            if coordinatesByID[toID] != nil, !seen.contains(toID) {
                orderedIDs.append(toID)
                seen.insert(toID)
            }
        }

        let currentID = route.currentFacility?.id
        let lastIndex = orderedIDs.count - 1

        return orderedIDs.enumerated().compactMap { index, id in
            guard let coordinate = coordinatesByID[id] else { return nil }

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
                name: namesByID[id] ?? "Facility \(id)",
                latitude: coordinate.lat,
                longitude: coordinate.lon,
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
    var locationsByCode: [Int: Location] = [:]
    var trackingInfo: TrackingInfo? = nil

    var body: some View {
        TrackingRouteMapView(
            route: route,
            locationsByCode: locationsByCode,
            trackingInfo: trackingInfo,
            isInteractive: true,
            waitsForWarmup: true
        )
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("In Transit Route Map") {
    TrackingRouteMapView(
        route: PreviewData.routeInTransit,
        isInteractive: false,
        waitsForWarmup: false
    )
    .frame(height: 280)
    .padding()
}

#Preview("Full Screen") {
    NavigationStack {
        TrackingRouteMapDetailView(route: PreviewData.routeInTransit)
    }
}

#Preview("Delivered Route Map") {
    TrackingRouteMapView(
        route: PreviewData.routeDelivered,
        isInteractive: false,
        waitsForWarmup: false
    )
    .frame(height: 280)
    .padding()
}

#Preview("No Coordinates") {
    TrackingRouteMapView(route: PreviewData.routeNoRouteFound, waitsForWarmup: false)
        .frame(height: 280)
        .padding()
}
