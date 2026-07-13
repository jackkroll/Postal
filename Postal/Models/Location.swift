import Foundation
import CoreLocation

struct Location: Codable, Identifiable, Hashable {
    let code: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let tier: Int

    var id: Int { code }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
