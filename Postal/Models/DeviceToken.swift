import Foundation

enum DevicePlatform: String, Codable, Hashable, Sendable {
    case ios
    case android
    case web
}

/// Body for `POST /api/me/device-tokens`.
struct RegisterDeviceTokenRequest: Codable, Hashable {
    let token: String
    let platform: DevicePlatform
    let appInstanceID: String?

    enum CodingKeys: String, CodingKey {
        case token
        case platform
        case appInstanceID = "app_instance_id"
    }

    init(token: String, platform: DevicePlatform = .ios, appInstanceID: String? = nil) {
        self.token = token
        self.platform = platform
        self.appInstanceID = appInstanceID
    }
}

/// Body for `DELETE /api/me/device-tokens`.
struct UnregisterDeviceTokenRequest: Codable, Hashable {
    let token: String
}

/// Response item from device-token list/register endpoints.
struct DeviceTokenSummary: Codable, Hashable, Identifiable {
    var id: String { token }

    let token: String
    let platform: String
    let appInstanceID: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case token
        case platform
        case appInstanceID = "app_instance_id"
        case updatedAt = "updated_at"
    }
}
