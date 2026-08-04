import MapKit
import UIKit

/// Forces MapKit/Metal to initialize once so the first real map is not a cold hitch.
enum MapKitWarmup {
    @MainActor
    private static var retainedMapView: MKMapView?
    @MainActor
    private static var isPrepared = false
    @MainActor
    private static var inFlight: Task<Void, Never>?

    /// Safe to call repeatedly; work runs once on the main actor.
    @MainActor
    static func prepareIfNeeded() {
        guard !isPrepared else { return }
        if inFlight != nil { return }

        inFlight = Task { @MainActor in
            defer { inFlight = nil }
            guard !isPrepared else { return }

            let mapView = MKMapView(frame: CGRect(x: -2, y: -2, width: 2, height: 2))
            mapView.alpha = 0.01
            mapView.isUserInteractionEnabled = false
            mapView.isHidden = false

            // Attaching to a live window completes tile/renderer setup more reliably.
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
                ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first {
                window.addSubview(mapView)
            }

            retainedMapView = mapView
            mapView.setRegion(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                    span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
                ),
                animated: false
            )

            // Give MapKit a beat to finish framework + first render pipeline work.
            try? await Task.sleep(for: .milliseconds(350))
            isPrepared = true

            try? await Task.sleep(for: .seconds(2))
            retainedMapView?.removeFromSuperview()
            retainedMapView = nil
        }
    }

    /// Awaits first-time warmup so a subsequent Map mount avoids the cold hitch.
    @MainActor
    static func prepare() async {
        prepareIfNeeded()
        while !isPrepared {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}
