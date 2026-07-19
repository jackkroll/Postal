import FirebaseCore
import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    // Kick off APNs early when permission is already granted so Settings
    // does not have to wait on a cold registration.
    Task { @MainActor in
      await AppServices.pushNotifications.registerIfAuthorized()
    }
    return true
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    Task { @MainActor in
      await AppServices.pushNotifications.registerIfAuthorized()
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
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        AppServices.api.setTokenProvider(AppServices.auth)
    }

    var body: some Scene {
        WindowGroup {
            NavigationView {
                RootView()
            }
        }
    }
}
