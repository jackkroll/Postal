import Foundation
import OSLog
import UIKit
import UserNotifications

enum PushNotificationError: LocalizedError {
    case permissionDenied
    case registrationFailed(String)
    case timedOutWaitingForToken

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission was denied. You can enable it in Settings."
        case let .registrationFailed(message):
            return message
        case .timedOutWaitingForToken:
            return "Timed out waiting for a push token. Make sure the device is online and try again."
        }
    }
}

protocol PushNotificationsProviding: AnyObject {
    var currentDeviceToken: String? { get }
    var authorizationStatus: UNAuthorizationStatus { get }
    var appInstanceID: String { get }
    func refreshAuthorizationStatus() async
    func registerIfAuthorized() async
    func requestAuthorizationAndToken() async throws -> String
    func handleDeviceToken(_ deviceToken: Data)
    func handleRegistrationFailure(_ error: Error)
    /// Stop receiving remote notifications and clear the cached APNs token.
    /// - Parameter userOptedOut: When true, automatic APNs re-registration is skipped until notifications are enabled again.
    func clearLocalRegistration(userOptedOut: Bool)
}

@MainActor
@Observable
final class PushNotificationService: NSObject, PushNotificationsProviding {
    static let shared = PushNotificationService()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var currentDeviceToken: String?
    private(set) var lastRegistrationError: String?

    private var tokenWaiters: [CheckedContinuation<String, Error>] = []
    private var tokenWaitGeneration = 0
    private let appInstanceIDKey = "postal.appInstanceID"
    private let deviceTokenKey = "postal.apnsDeviceToken"
    private let userOptedOutKey = "postal.notificationsUserOptedOut"
    private let logger = Logger(subsystem: "Postal", category: "Push")

    private var userOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: userOptedOutKey) }
        set { UserDefaults.standard.set(newValue, forKey: userOptedOutKey) }
    }

    var appInstanceID: String {
        if let existing = UserDefaults.standard.string(forKey: appInstanceIDKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: appInstanceIDKey)
        return created
    }

    override init() {
        super.init()
        if let cached = UserDefaults.standard.string(forKey: deviceTokenKey), !cached.isEmpty {
            currentDeviceToken = cached
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Warm APNs registration early so a token is ready before Settings is opened.
    func registerIfAuthorized() async {
        await refreshAuthorizationStatus()
        guard !userOptedOut else { return }
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        default:
            break
        }
    }

    func requestAuthorizationAndToken() async throws -> String {
        userOptedOut = false
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        await refreshAuthorizationStatus()

        guard granted else {
            throw PushNotificationError.permissionDenied
        }

        lastRegistrationError = nil
        UIApplication.shared.registerForRemoteNotifications()

        // Prefer a fresh callback, but fall back to a known token so enable
        // does not hang when APNs is slow or already delivered between calls.
        if let existing = currentDeviceToken {
            return existing
        }

        return try await waitForDeviceToken(timeoutSeconds: 30)
    }

    func handleDeviceToken(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        currentDeviceToken = hex
        lastRegistrationError = nil
        UserDefaults.standard.set(hex, forKey: deviceTokenKey)
        logger.info("Received APNs device token (\(hex.prefix(8))…)")

        resumeWaiters(returning: hex)
    }

    func handleRegistrationFailure(_ error: Error) {
        lastRegistrationError = error.localizedDescription
        logger.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
        failWaiters(with: PushNotificationError.registrationFailed(error.localizedDescription))
    }

    func clearLocalRegistration(userOptedOut: Bool = false) {
        currentDeviceToken = nil
        lastRegistrationError = nil
        UserDefaults.standard.removeObject(forKey: deviceTokenKey)
        UIApplication.shared.unregisterForRemoteNotifications()
        self.userOptedOut = userOptedOut
        logger.info("Cleared local APNs registration (userOptedOut=\(userOptedOut))")
    }

    private func waitForDeviceToken(timeoutSeconds: Double) async throws -> String {
        tokenWaitGeneration += 1
        let generation = tokenWaitGeneration

        return try await withCheckedThrowingContinuation { continuation in
            if let existing = currentDeviceToken {
                continuation.resume(returning: existing)
                return
            }

            tokenWaiters.append(continuation)

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                guard generation == self.tokenWaitGeneration else { return }

                if let existing = self.currentDeviceToken {
                    self.resumeWaiters(returning: existing)
                    return
                }

                if let message = self.lastRegistrationError {
                    self.failWaiters(with: PushNotificationError.registrationFailed(message))
                    return
                }

                self.logger.error("Timed out waiting for APNs device token")
                self.failWaiters(with: PushNotificationError.timedOutWaitingForToken)
            }
        }
    }

    private func resumeWaiters(returning token: String) {
        guard !tokenWaiters.isEmpty else { return }
        let waiters = tokenWaiters
        tokenWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: token)
        }
    }

    private func failWaiters(with error: Error) {
        guard !tokenWaiters.isEmpty else { return }
        let waiters = tokenWaiters
        tokenWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(throwing: error)
        }
    }
}
