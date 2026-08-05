import SwiftUI

struct TrackingView: View {
    @State var viewmodel: ViewModel
    @State private var showTrackingCopiedAlert = false

    var body: some View {
        ZStack(alignment: .top) {
            if let route = viewmodel.trackingRoute {
                LinearGradient(
                    colors: [route.statusColor(), route.statusColor().opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .ignoresSafeArea(edges: .top)
                .animation(.easeInOut, value: viewmodel.trackingRoute)
            }
            Form {
                if viewmodel.isRecipient, let letterLink = viewmodel.letterReadingLink {
                    viewLetterSection(letterLink, prominent: true)
                }

                if let route = viewmodel.trackingRoute {
                    Section {
                        TrackingStatusHeader(
                            route: route,
                            summary: route.statusSummary(),
                            expectedDeliveryTime: viewmodel.expectedDeliveryTime,
                            deliveredAt: route.deliveredAt
                        )
                            .listRowSeparator(.hidden)
                            .padding(4)
                            .listRowBackground(StatusCardBackground(tint: route.statusColor()))
                    }
                    .listSectionSeparator(.hidden)
                }

                if viewmodel.trackingRoute == nil {
                    Section {
                        Button(viewmodel.isLoading ? "Looking Up…" : "Track") {
                            Task { await viewmodel.lookupTracking() }
                        }
                        .disabled(viewmodel.isLoading || viewmodel.trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if let route = viewmodel.trackingRoute,
                   !TrackingRouteMapView.stops(
                    from: route,
                    locationsByCode: viewmodel.locationsByCode,
                    trackingInfo: viewmodel.trackingInfo
                   ).isEmpty {
                    Section("Route") {
                        Button {
                            viewmodel.pushRouteMap()
                        } label: {
                            TrackingRouteMapView(
                                route: route,
                                locationsByCode: viewmodel.locationsByCode,
                                trackingInfo: viewmodel.trackingInfo,
                                isInteractive: true,
                                waitsForWarmup: true
                            )
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .accessibilityHint("Opens full screen map")
                    }
                }

                if let route = viewmodel.trackingRoute, !route.events.isEmpty {
                    Section("Timeline") {
                        ForEach(route.events.reversed()) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.eventType.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.headline)
                                if let facilityName = eventFacilityName(event, in: route) {
                                    Text(facilityName)
                                        .foregroundStyle(.secondary)
                                }
                                if let timestamp = event.recordedAt ?? event.scheduledFor {
                                    Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !viewmodel.isRecipient, let letterLink = viewmodel.letterReadingLink {
                    viewLetterSection(letterLink, prominent: false)
                }

                if let errorMessage = viewmodel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .refreshable {
                async let lookup = viewmodel.lookupTracking()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await lookup
            }
            .navigationTitle(viewmodel.currentStatus() ?? "")
            .animation(.easeInOut,value: viewmodel.currentStatus())
            .navigationDestination(item: $viewmodel.presentedRouteMap) { route in
                TrackingRouteMapDetailView(
                    route: route,
                    locationsByCode: viewmodel.locationsByCode,
                    trackingInfo: viewmodel.trackingInfo
                )
            }
            .task {
                MapKitWarmup.prepareIfNeeded()
            }
            .toolbar {
                Button {
                    UIPasteboard.general.string = DeepLink.trackURL(for: viewmodel.trackingNumber).absoluteString
                    showTrackingCopiedAlert = true
                } label: {
                    Label("Copy", systemImage: "document.on.document.fill")
                }
            }
            .alert("Copied", isPresented: $showTrackingCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tracking link copied to clipboard.")
            }
        }
    }

    @ViewBuilder
    private func viewLetterSection(
        _ link: (shipmentID: String, metadata: LetterMetadata),
        prominent: Bool
    ) -> some View {
        Section {
            NavigationLink(
                value: ViewRoute.read(
                    shipmentID: link.shipmentID,
                    metadata: link.metadata,
                    service: viewmodel.letterService
                )
            ) {
                if prominent {
                    Label("View Letter", systemImage: "envelope.open.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    Text("View Letter")
                }
            }
        }
    }

    private func facilityName(for facilityID: Int, in route: TrackingRoute) -> String {
        (route.currentFacility?.id == facilityID ? route.currentFacility?.name : nil)
            ?? "Facility \(facilityID)"
    }

    private func eventFacilityName(_ event: ShipmentTrackingEvent, in route: TrackingRoute) -> String? {
        if let facility = event.facility {
            return facility.name
        }
        if let facilityID = event.facilityID {
            return facilityName(for: facilityID, in: route)
        }
        return nil
    }
}

private struct TrackingStatusHeader: View {
    let route: TrackingRoute
    let summary: TrackingStatusSummary
    let expectedDeliveryTime: Date?
    let deliveredAt: Date?

    var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: route.statusIcon())
                        .font(.title2)
                        .foregroundStyle(route.statusColor())
                        .frame(width: 48, height: 48)
                        .background(route.statusColor().opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer()
                    if let expectedDeliveryTime = expectedDeliveryTime {
                        HStack {
                            Text("\(route.status == .delivered ? "Arrived": "Expected") \(expectedDeliveryTime.formatted(date: .long, time: .omitted))")
                        }
                        .foregroundStyle(.secondary)
                        .bold()
                    }
                }
                
                Text(summary.message)
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let context = summary.context {
                    Text(context)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var arrivalLine: String? {
        if route.status == .delivered, let deliveredAt {
            return "Arrived \(deliveredAt.formatted(date: .abbreviated, time: .omitted))"
        }
        if let expectedDeliveryTime {
            let label = route.status == .delivered ? "Arrived" : "Expected"
            return "\(label) \(expectedDeliveryTime.formatted(date: .abbreviated, time: .omitted))"
        }
        if route.status == .failed || !route.routeFound {
            return "ETA unavailable"
        }
        return nil
    }
}

private struct StatusCardBackground: View {
    let tint: Color
    var cornerRadius: CGFloat = 16

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(tint.opacity(0.2)), in: .rect(cornerRadius: cornerRadius))
        } else {
            shape
                .fill(.ultraThinMaterial)
        }
    }
}

extension TrackingView {
    @Observable
    class ViewModel {
        let api: APIClient
        let letterService: LetterContentProviding
        var trackingNumber: String
        var letterSummary: LetterSummary?
        var isRecipient: Bool
        var trackingInfo: TrackingInfo?
        var trackingRoute: TrackingRoute?
        var locationsByCode: [Int: Location] = [:]
        var presentedRouteMap: TrackingRoute?
        var errorMessage: String?
        var isLoading = false

        var shipmentID: String? {
            if let letterSummary {
                return letterSummary.shipmentID
            }
            let number = trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            return number.isEmpty ? nil : number
        }

        var letterMetadata: LetterMetadata? {
            letterSummary?.letterMetadata
        }

        var letterReadingLink: (shipmentID: String, metadata: LetterMetadata)? {
            guard let shipmentID, let letterMetadata else { return nil }
            return (shipmentID, letterMetadata)
        }

        /// Prefer live public-track ETA; fall back to shipment-backed letter summary.
        var expectedDeliveryTime: Date? {
            trackingInfo?.expectedDeliveryTime ?? letterSummary?.expectedDeliveryTime
        }

        init(
            apiClient: APIClient,
            letterService: LetterContentProviding = LetterContentService(),
            trackingNumber: String? = nil,
            letterSummary: LetterSummary? = nil,
            isRecipient: Bool = false,
            autoLookup: Bool = true
        ) {
            self.api = apiClient
            self.letterService = letterService
            self.letterSummary = letterSummary
            self.isRecipient = isRecipient
            if let trackingNumber {
                self.trackingNumber = trackingNumber
                if autoLookup {
                    Task { await lookupTracking() }
                }
            } else {
                self.trackingNumber = ""
            }
        }

        func pushRouteMap() {
            presentedRouteMap = trackingRoute
        }

        func lookupTracking() async {
            let number = trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !number.isEmpty else { return }

            isLoading = true
            errorMessage = nil
            trackingInfo = nil
            trackingRoute = nil
            locationsByCode = [:]
            defer { isLoading = false }

            do {
                async let summaryRequest: TrackingInfo = api.get(.publicTrack(trackingNumber: number))
                async let routeRequest: TrackingRoute = api.get(.publicTrackRoute(trackingNumber: number))
                let summary = try await summaryRequest
                let route = try await routeRequest
                trackingInfo = summary
                trackingRoute = route
                if let letterSummary {
                    self.letterSummary = letterSummary.attaching(tracking: summary)
                }
                // Resolve coordinates off the critical path so status/timeline paint first.
                Task { await resolveMapLocations(for: route, trackingInfo: summary) }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        /// Live `/route` facilities omit coordinates; resolve them via `/api/locations/{code}`.
        func resolveMapLocations(for route: TrackingRoute, trackingInfo: TrackingInfo?) async {
            let codes = TrackingRouteMapView.facilityIDs(in: route, trackingInfo: trackingInfo)
            guard !codes.isEmpty else { return }

            var fetched: [Int: Location] = [:]
            await withTaskGroup(of: (Int, Location?).self) { group in
                for code in codes where locationsByCode[code] == nil {
                    group.addTask {
                        (code, try? await self.api.fetchLocation(code: code))
                    }
                }
                for await (code, location) in group {
                    if let location {
                        fetched[code] = location
                    }
                }
            }

            guard !Task.isCancelled else { return }
            locationsByCode.merge(fetched) { _, new in new }
        }

        func lookupLocation(code: Int) async throws -> Location {
            try await api.fetchLocation(code: code)
        }
        
        func currentStatus() -> String? {
            trackingRoute?.status.displayTitle ?? trackingInfo?.status.displayTitle
        }
        
    }
}

#Preview("Empty Lookup") {
    NavigationStack {
        TrackingView(viewmodel: .preview())
    }
}

#Preview("In Transit") {
    NavigationStack {
        TrackingView(viewmodel: .preview(
            trackingNumber: PreviewData.inTransitTrackingNumber,
            route: PreviewData.routeInTransit,
            trackingInfo: PreviewData.trackingInfoInTransit
        ))
    }
}

#Preview("Delivered With Letter") {
    NavigationStack {
        TrackingView(viewmodel: .preview(
            trackingNumber: PreviewData.deliveredTrackingNumber,
            route: PreviewData.routeDelivered,
            trackingInfo: PreviewData.trackingInfoDelivered,
            letterSummary: PreviewData.letterDelivered
        ))
    }
}

#Preview("Inbound With Letter") {
    NavigationStack {
        TrackingView(viewmodel: .preview(
            trackingNumber: PreviewData.deliveredTrackingNumber,
            route: PreviewData.routeDelivered,
            trackingInfo: PreviewData.trackingInfoDelivered,
            letterSummary: PreviewData.letterDelivered,
            isRecipient: true
        ))
    }
}

#Preview("Delivered") {
    NavigationStack {
        TrackingView(viewmodel: .preview(
            trackingNumber: PreviewData.deliveredTrackingNumber,
            route: PreviewData.routeDelivered,
            trackingInfo: PreviewData.trackingInfoDelivered
        ))
    }
}

#Preview("Awaiting Pickup") {
    NavigationStack {
        TrackingView(viewmodel: .preview(
            trackingNumber: PreviewData.awaitingPickupTrackingNumber,
            route: PreviewData.routeAwaitingPickup
        ))
    }
}

#Preview("Loading") {
    NavigationStack {
        TrackingView(viewmodel: .preview(
            trackingNumber: PreviewData.inTransitTrackingNumber,
            isLoading: true
        ))
    }
}

#Preview("Not Found") {
    NavigationStack {
        TrackingView(viewmodel: .preview(
            trackingNumber: "00000000-0000-0000-0000-000000000000",
            errorMessage: "Request failed (404): Shipment not found."
        ))
    }
}
