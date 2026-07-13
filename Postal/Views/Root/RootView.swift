import SwiftUI

struct RootView: View {
    @State private var router = Router()
    @State private var authState = AuthStateObserver()

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
                Router.view(for: route)
            }
            .environment(router)
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
            LettersListView(viewmodel: .preview())
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
            LettersListView(viewmodel: .preview(letters: [PreviewData.letterInTransit]))
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
