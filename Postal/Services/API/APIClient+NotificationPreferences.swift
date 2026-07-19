import Foundation

extension APIClient {
    func getNotificationPreferences() async throws -> NotificationPreferencesSummary {
        try await get(.meNotificationPreferences, authenticated: true)
    }

    @discardableResult
    func updateNotificationPreferences(
        sent: SentNotificationMode,
        inbound: InboundNotificationMode
    ) async throws -> NotificationPreferencesSummary {
        try await put(
            .updateNotificationPreferences,
            body: UpdateNotificationPreferencesRequest(sent: sent, inbound: inbound),
            authenticated: true
        )
    }
}
