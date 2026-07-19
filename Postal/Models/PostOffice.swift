import Foundation
import CoreLocation

struct PostOffice: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let lat: Double?
    let lon: Double?
    let tier: Int?

    init(id: Int, name: String, lat: Double? = nil, lon: Double? = nil, tier: Int? = nil) {
        self.id = id
        self.name = name
        self.lat = lat
        self.lon = lon
        self.tier = tier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
            ?? container.decode(Int.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
            ?? container.decodeIfPresent(Double.self, forKey: .latitude)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
            ?? container.decodeIfPresent(Double.self, forKey: .longitude)
        tier = try container.decodeIfPresent(Int.self, forKey: .tier)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(lat, forKey: .lat)
        try container.encodeIfPresent(lon, forKey: .lon)
        try container.encodeIfPresent(tier, forKey: .tier)
    }
    
    func getLocationDetails(latitude: Double, longitude: Double) async throws -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()

        return try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }

                if let city = placemark.locality, let state = placemark.administrativeArea {
                    continuation.resume(returning: "\(city), \(state)")
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func getLocationDetails() async throws -> String? {
        guard let lat, let lon else { return nil }
        return try await getLocationDetails(latitude: lat, longitude: lon)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case lat
        case lon
        case latitude
        case longitude
        case tier
    }
}
