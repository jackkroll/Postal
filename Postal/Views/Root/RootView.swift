import SwiftUI
import RevenueCat

struct RootView: View {
    @State private var router = Router()
    @State private var authState = AuthStateObserver()
    @Bindable private var onboarding = AppServices.onboarding

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                if authState.isSignedIn {
                    MainTabView()
                } else {
                    SignInView(viewmodel: .init(auth: AppServices.auth))
                }
            }
            .navigationDestination(for: ViewRoute.self) { route in
                // Destinations do not reliably inherit environment from the stack root.
                Router.view(for: route)
                    .environment(router)
            }
        }
        .environment(router)
        .fullScreenCover(isPresented: onboardingCoverBinding) {
            OnboardingFlowView(store: onboarding)
        }
        .onOpenURL(perform: handleIncomingURL)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            handleIncomingURL(url)
        }
        .task(id: authState.userID) {
            if let userID = authState.userID {
                MapKitWarmup.prepareIfNeeded()
                onboarding.load(userID: userID)
                await Self.handleSignedIn(userID: userID)
                await Self.bootstrapOnboarding(onboarding)
            } else {
                onboarding.clear()
                await Self.handleSignedOut()
            }
        }
    }

    /// Presents onboarding only after progress is loaded and still incomplete.
    private var onboardingCoverBinding: Binding<Bool> {
        Binding(
            get: { authState.isSignedIn && onboarding.shouldPresent },
            set: { _ in }
        )
    }

    /// Opens `https://postal.jackk.dev/track/{number}` (and `postal://track/{number}`).
    private func handleIncomingURL(_ url: URL) {
        guard let deepLink = DeepLink.parse(url) else { return }
        router.open(deepLink)
    }

    /// Decide whether this account needs onboarding (new) or is grandfathered (existing).
    private static func bootstrapOnboarding(_ onboarding: OnboardingStore) async {
        do {
            let mailboxes = try await AppServices.api.listOwnedMailboxes()
            await MainActor.run {
                onboarding.bootstrapIfNeeded(ownedMailboxCount: mailboxes.count)
                onboarding.skipClaimIfNeeded(ownedMailboxes: mailboxes)
            }
        } catch {
            guard !error.isPostalCancellation else { return }
            // Offline first launch with no mailbox history: still offer onboarding.
            await MainActor.run {
                if onboarding.progress == nil {
                    onboarding.bootstrapIfNeeded(ownedMailboxCount: 0)
                }
            }
        }
    }

    /// Link Firebase uid to RevenueCat, refresh entitlements, and re-register push.
    private static func handleSignedIn(userID: String) async {
        let aligned = await AppServices.purchasesIdentity.sync(firebaseUserID: userID)
        guard !Task.isCancelled else { return }
        // Prefer a confirmed RC identity before reading STAMP / refreshing.
        guard aligned || AppServices.purchasesIdentity.isAligned(with: userID) else { return }
        await AppServices.entitlements.refresh()
        await registerForNotificationsIfAuthorized()
    }

    /// Reset RevenueCat to an anonymous user and clear local entitlements.
    private static func handleSignedOut() async {
        _ = await AppServices.purchasesIdentity.sync(firebaseUserID: nil)
        guard !Task.isCancelled else { return }
        AppServices.entitlements.clear()
    }

    /// Re-register the device token with the server after sign-in when permission
    /// is already granted (e.g. user signed out and back in).
    private static func registerForNotificationsIfAuthorized() async {
        let push = AppServices.pushNotifications
        do {
            guard let token = try await push.deviceTokenIfAuthorized() else { return }
            try await AppServices.api.registerDeviceToken(
                token,
                platform: .ios,
                appInstanceID: push.appInstanceID
            )
        } catch {
            // Best-effort; Settings still allows manual registration.
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        LettersListView()
    }
}

#Preview("Signed Out") {
    NavigationStack {
        SignInView(viewmodel: .preview())
    }
}

#Preview("Signed In Tabs") {
    NavigationStack {
        TabView {
            LettersListView(viewmodel: .preview(), loadsOnAppear: false)
                .tabItem {
                    Label("My Letters", systemImage: "envelope")
                }

            TrackingView(viewmodel: .preview())
                .tabItem {
                    Label("Track", systemImage: "location")
                }
        }
    }
}

#Preview("Signed In — Tracking Detail") {
    NavigationStack {
        TabView {
            LettersListView(
                viewmodel: .preview(letters: [PreviewData.letterInTransit]),
                loadsOnAppear: false
            )
            .tabItem {
                Label("My Letters", systemImage: "envelope")
            }

            TrackingView(viewmodel: .preview(
                trackingNumber: PreviewData.inTransitTrackingNumber,
                route: PreviewData.routeInTransit
            ))
            .tabItem {
                Label("Track", systemImage: "location")
            }
        }
    }
}
