import Foundation

extension APIClient {
    func listDeviceTokens() async throws -> [DeviceTokenSummary] {
        try await get(.meDeviceTokens, authenticated: true)
    }

    @discardableResult
    func registerDeviceToken(
        _ token: String,
        platform: DevicePlatform = .ios,
        appInstanceID: String? = nil
    ) async throws -> DeviceTokenSummary {
        try await post(
            .registerDeviceToken,
            body: RegisterDeviceTokenRequest(
                token: token,
                platform: platform,
                appInstanceID: appInstanceID
            ),
            authenticated: true
        )
    }

    func unregisterDeviceToken(_ token: String) async throws {
        let _: [String: Bool] = try await delete(
            .unregisterDeviceToken,
            body: UnregisterDeviceTokenRequest(token: token),
            authenticated: true
        )
    }
}
