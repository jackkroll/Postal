import SwiftUI

struct TrackingView: View {
    @State var viewmodel: ViewModel
    @State private var showTrackingCopiedAlert = false

    var body: some View {
        ZStack(alignment: .top) {
            if let presentation = viewmodel.statusPresentation {
                LinearGradient(
                    colors: [presentation.tint, presentation.tint.opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .ignoresSafeArea(edges: .top)
                .animation(.easeInOut, value: presentation.title)
            }
            Form {
                if viewmodel.isRecipient, let letterLink = viewmodel.letterReadingLink {
                    viewLetterSection(letterLink, prominent: true)
                }

                if let presentation = viewmodel.statusPresentation {
                    Section {
                        TrackingStatusHeader(presentation: presentation)
                            .listRowSeparator(.hidden)
                            .padding(4)
                            .listRowBackground(StatusCardBackground(tint: presentation.tint))
                    }
                    .listSectionSeparator(.hidden)
                }

                if viewmodel.showsManualTrackAction {
                    Section {
                        Button(viewmodel.isLoading ? "Looking Up…" : "Track") {
                            Task { await viewmodel.lookupTracking() }
                        }
                        .disabled(viewmodel.isLoading || viewmodel.trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if viewmodel.showsRetryAction {                        Button(viewmodel.isLoading ? "Looking Up…" : "Try Again") {
                            Task { await viewmodel.lookupTracking() }
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .disabled(viewmodel.isLoading)
                        .frame(maxWidth: .infinity)
                        
                        
                        
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
            }
            .scrollContentBackground(.hidden)
            .refreshable {
                async let lookup = viewmodel.lookupTracking()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await lookup
            }
            .navigationTitle(viewmodel.currentStatus() ?? "")
            .animation(.easeInOut, value: viewmodel.currentStatus())
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

struct TrackingStatusPresentation: Equatable {
    let tint: Color
    let icon: String
    let title: String
    let summary: TrackingStatusSummary
    let expectedDeliveryTime: Date?
    let deliveredAt: Date?
    let arrivalVerb: String
    let showsProgress: Bool

    static func loaded(
        route: TrackingRoute,
        expectedDeliveryTime: Date?,
        detail: String? = nil
    ) -> TrackingStatusPresentation {
        TrackingStatusPresentation(
            tint: route.statusColor(),
            icon: route.statusIcon(),
            title: route.status.displayTitle,
            summary: route.statusSummary(detail: detail),
            expectedDeliveryTime: expectedDeliveryTime,
            deliveredAt: route.deliveredAt,
            arrivalVerb: arrivalVerb(for: route.status),
            showsProgress: false
        )
    }

    static func loading() -> TrackingStatusPresentation {
        TrackingStatusPresentation(
            tint: .blue,
            icon: "magnifyingglass",
            title: "Looking Up",
            summary: TrackingStatusSummary(
                title: "Looking Up",
                message: "Looking up your letter…",
                context: "This usually only takes a moment."
            ),
            expectedDeliveryTime: nil,
            deliveredAt: nil,
            arrivalVerb: "Expected",
            showsProgress: true
        )
    }

    static func unavailable(detail: String?) -> TrackingStatusPresentation {
        let isNotFound = detail?.localizedCaseInsensitiveContains("not found") == true
        return TrackingStatusPresentation(
            tint: ShipmentStatus.failed.tintColor,
            icon: ShipmentStatus.failed.iconName,
            title: "Not Found",
            summary: TrackingStatusSummary(
                title: ShipmentStatus.failed.displayTitle,
                message: isNotFound
                    ? "We couldn't find tracking details for this number."
                    : "We couldn't load tracking details.",
                context: detail
            ),
            expectedDeliveryTime: nil,
            deliveredAt: nil,
            arrivalVerb: "Expected",
            showsProgress: false
        )
    }

    private static func arrivalVerb(for status: ShipmentStatus) -> String {
        switch status {
        case .delivered: "Arrived"
        case .held: "Unlocks"
        default: "Expected"
        }
    }
}

private struct TrackingStatusHeader: View {
    let presentation: TrackingStatusPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Group {
                    if presentation.showsProgress {
                        ProgressView()
                            .tint(presentation.tint)
                    } else {
                        Image(systemName: presentation.icon)
                            .font(.title2)
                            .foregroundStyle(presentation.tint)
                    }
                }
                .frame(width: 48, height: 48)
                .background(presentation.tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
                if let expectedDeliveryTime = presentation.expectedDeliveryTime {
                    HStack {
                        Text("\(presentation.arrivalVerb) \(expectedDeliveryTime.formatted(date: .long, time: .omitted))")
                    }
                    .foregroundStyle(.secondary)
                    .bold()
                }
            }

            Text(presentation.summary.message)
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)

            if let context = presentation.summary.context {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

        var statusPresentation: TrackingStatusPresentation? {
            if let route = trackingRoute {
                let detail = route.status == .failed ? friendlyErrorDetail : nil
                return .loaded(
                    route: route,
                    expectedDeliveryTime: expectedDeliveryTime,
                    detail: detail
                )
            }
            if errorMessage != nil {
                return .unavailable(detail: friendlyErrorDetail)
            }
            if isLoading, !trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .loading()
            }
            return nil
        }

        var showsManualTrackAction: Bool {
            trackingRoute == nil
                && errorMessage == nil
                && !isLoading
                && !trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var showsRetryAction: Bool {
            trackingRoute == nil && errorMessage != nil
        }

        /// Prefer a short human detail over raw `Request failed (404): …` copy.
        private var friendlyErrorDetail: String? {
            guard let errorMessage, !errorMessage.isEmpty else { return nil }
            if let apiError = errorMessage.apiFailureDetail {
                return apiError
            }
            return errorMessage
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
                // Drop stale payload so the unavailable status card can take over.
                trackingInfo = nil
                trackingRoute = nil
                locationsByCode = [:]
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
            statusPresentation?.title
                ?? trackingRoute?.status.displayTitle
                ?? trackingInfo?.status.displayTitle
        }
    }
}

private extension String {
    /// Pulls the server message out of `Request failed (404): Shipment not found.` style errors.
    var apiFailureDetail: String? {
        guard let markerRange = range(of: "): ") else { return nil }
        let detail = String(self[markerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? nil : detail
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
