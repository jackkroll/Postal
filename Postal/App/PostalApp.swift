import FirebaseAuth
import FirebaseCore
import OSLog
import StoreKit
import SwiftUI
import UIKit
import UserNotifications
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate {
  private static let purchasesLog = Logger(subsystem: "Postal", category: "Purchases")

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    configurePurchases()
    // Kick off APNs early when permission is already granted so Settings
    // does not have to wait on a cold registration.
    Task { @MainActor in
      await AppServices.pushNotifications.clearAppIconBadge()
      await AppServices.pushNotifications.registerIfAuthorized()
    }
    return true
  }

  /// Configure RevenueCat after Firebase so a restored session can be identified
  /// immediately — avoids a cold-start anonymous ID that occasionally never gets replaced.
  private func configurePurchases() {
    guard !Purchases.isConfigured else { return }
    Purchases.logLevel = .debug
    let apiKey = AppConfiguration.revenueCatAPIKey
    let keyPrefix = String(apiKey.prefix(5))
    if let uid = Auth.auth().currentUser?.uid {
      Self.purchasesLog.info("Configuring RC keyPrefix=\(keyPrefix, privacy: .public) appUserID=firebase")
      Purchases.configure(withAPIKey: apiKey, appUserID: uid)
    } else {
      Self.purchasesLog.info("Configuring RC keyPrefix=\(keyPrefix, privacy: .public) appUserID=anonymous")
      Purchases.configure(withAPIKey: apiKey)
    }
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("[Postal Push] didRegisterForRemoteNotifications tokenBytes=\(deviceToken.count)")
    deliverPushCallback {
      AppServices.pushNotifications.handleDeviceToken(deviceToken)
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[Postal Push] didFailToRegister: \(error.localizedDescription)")
    deliverPushCallback {
      AppServices.pushNotifications.handleRegistrationFailure(error)
    }
  }

  /// Prefer a synchronous main-actor handoff so a fast APNs callback cannot
  /// land between `registerForRemoteNotifications()` and waiter setup.
  private func deliverPushCallback(_ body: @MainActor @escaping () -> Void) {
    if Thread.isMainThread {
      MainActor.assumeIsolated {
        body()
      }
    } else {
      Task { @MainActor in
        body()
      }
    }
  }
}


@main
struct PostalApp: App {
    // register app delegate for Firebase + RevenueCat setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppServices.api.setTokenProvider(AppServices.auth)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { @MainActor in
                await AppServices.pushNotifications.clearAppIconBadge()
                await AppServices.pushNotifications.registerIfAuthorized()
                // Recover if a prior RC logIn was cancelled or failed while backgrounded.
                let uid = Auth.auth().currentUser?.uid
                if !AppServices.purchasesIdentity.isAligned(with: uid) {
                    let aligned = await AppServices.purchasesIdentity.sync(firebaseUserID: uid)
                    if aligned, uid != nil {
                        await AppServices.entitlements.refresh()
                    }
                }
            }
        }
    }
}
