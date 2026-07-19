import SwiftUI

struct TrackingView: View {
    @State var viewmodel: ViewModel

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
                if let route = viewmodel.trackingRoute {
                    Section {
                        TrackingStatusHeader(route: route, summary: route.statusSummary())
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
                
                if let shipmentID = viewmodel.shipmentID, let metadata = viewmodel.letterMetadata{
                    NavigationLink(value: ViewRoute.read(shipmentID: shipmentID, metadata: metadata, service: viewmodel.letterService )) {
                        Text("View Letter")
                    }
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
            .toolbar {
                Button {
                    UIPasteboard.general.string = viewmodel.trackingNumber
                } label: {
                    Label("Copy", systemImage: "document.on.document.fill")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: route.statusIcon())
                .font(.title2)
                .foregroundStyle(route.statusColor())
                .frame(width: 48, height: 48)
                .background(route.statusColor().opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
        var trackingRoute: TrackingRoute?
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

        init(
            apiClient: APIClient,
            letterService: LetterContentProviding = LetterContentService(),
            trackingNumber: String? = nil,
            letterSummary: LetterSummary? = nil,
            autoLookup: Bool = true
        ) {
            self.api = apiClient
            self.letterService = letterService
            self.letterSummary = letterSummary
            if let trackingNumber {
                self.trackingNumber = trackingNumber
                if autoLookup {
                    Task { await lookupTracking() }
                }
            } else {
                self.trackingNumber = ""
            }
        }

        func lookupTracking() async {
            let number = trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !number.isEmpty else { return }

            isLoading = true
            errorMessage = nil
            trackingRoute = nil
            defer { isLoading = false }

            do {
                trackingRoute = try await api.get(.publicTrackRoute(trackingNumber: number))
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func lookupLocation(code: Int) async throws -> Location {
            try await api.fetchLocation(code: code)
        }
        
        func currentStatus() -> String? {
            trackingRoute?.status.displayTitle
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
            route: PreviewData.routeInTransit
        ))
    }
}

#Preview("Delivered With Letter") {
    NavigationStack {
        TrackingView(viewmodel: .preview(
            trackingNumber: PreviewData.deliveredTrackingNumber,
            route: PreviewData.routeDelivered,
            letterSummary: PreviewData.letterDelivered
        ))
    }
}

#Preview("Delivered") {
    NavigationStack {
        TrackingView(viewmodel: .preview(
            trackingNumber: PreviewData.deliveredTrackingNumber,
            route: PreviewData.routeDelivered
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

