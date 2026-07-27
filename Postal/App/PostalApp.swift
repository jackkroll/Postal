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
    // Verbose while diagnosing error 23 (StoreKit returns no products on device/TestFlight).
    Purchases.logLevel = .verbose
    let apiKey = AppConfiguration.revenueCatAPIKey
    let keyPrefix = String(apiKey.prefix(5))
    if let uid = Auth.auth().currentUser?.uid {
      Self.purchasesLog.info("Configuring RC keyPrefix=\(keyPrefix, privacy: .public) appUserID=firebase")
      Purchases.configure(withAPIKey: apiKey, appUserID: uid)
    } else {
      Self.purchasesLog.info("Configuring RC keyPrefix=\(keyPrefix, privacy: .public) appUserID=anonymous")
      Purchases.configure(withAPIKey: apiKey)
    }
    Task {
      await Self.logStoreKitProductsDiagnostics()
      await Self.logOfferingsDiagnostics()
    }
  }

  /// Asks StoreKit 2 directly (bypassing RC) so we can see Apple’s empty-catalog
  /// response that becomes RevenueCat error 23.
  private static func logStoreKitProductsDiagnostics() async {
    let ids: Set<String> = ["plus_monthly", "plus_annual"]
    purchasesLog.info("StoreKit Product.products request for \(ids.sorted().joined(separator: ","), privacy: .public)")
    do {
      let products = try await Product.products(for: ids)
      let returned = Set(products.map(\.id))
      let missing = ids.subtracting(returned).sorted()
      purchasesLog.info("StoreKit returned count=\(products.count) ids=\(returned.sorted().joined(separator: ","), privacy: .public)")
      for product in products {
        purchasesLog.info(
          "StoreKit product \(product.id, privacy: .public) type=\(String(describing: product.type), privacy: .public) price=\(product.displayPrice, privacy: .public)"
        )
      }
      if !missing.isEmpty {
        purchasesLog.error(
          "StoreKit missing product IDs (Apple returned empty for these): \(missing.joined(separator: ","), privacy: .public)"
        )
      }
    } catch {
      let nsError = error as NSError
      purchasesLog.error(
        "StoreKit Product.products failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code) \(nsError.localizedDescription, privacy: .public)"
      )
    }
  }

  /// Probes offerings right after configure so Console shows whether RC IDs
  /// resolved and whether StoreKit returned products (error 23 path).
  private static func logOfferingsDiagnostics() async {
    do {
      let offerings = try await Purchases.shared.offerings()
      let current = offerings.current
      let packageCount = current?.availablePackages.count ?? 0
      purchasesLog.info(
        "Offerings OK count=\(offerings.all.count) current=\(current?.identifier ?? "nil", privacy: .public) packages=\(packageCount)"
      )
      for package in current?.availablePackages ?? [] {
        purchasesLog.info(
          "Package \(package.identifier, privacy: .public) product=\(package.storeProduct.productIdentifier, privacy: .public) price=\(package.storeProduct.localizedPriceString, privacy: .public)"
        )
      }
      if current == nil || packageCount == 0 {
        purchasesLog.error(
          "Current offering empty after RC fetch — StoreKit likely returned no products for the dashboard IDs"
        )
      }
    } catch {
      let nsError = error as NSError
      purchasesLog.error(
        "Offerings fetch failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code) \(nsError.localizedDescription, privacy: .public)"
      )
      if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
        purchasesLog.error(
          "Underlying domain=\(underlying.domain, privacy: .public) code=\(underlying.code) \(underlying.localizedDescription, privacy: .public)"
        )
      }
      for (key, value) in nsError.userInfo where key != NSUnderlyingErrorKey {
        purchasesLog.error("userInfo[\(key, privacy: .public)]=\(String(describing: value), privacy: .public)")
      }
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
                        async let entitlementsRefresh: Void = AppServices.entitlements.refresh()
                        async let limitsRefresh: Void = AppServices.letterLimits.refresh()
                        _ = await (entitlementsRefresh, limitsRefresh)
                    }
                }
            }
        }
    }
}
