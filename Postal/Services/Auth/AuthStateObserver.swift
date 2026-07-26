import FirebaseAuth
import Observation

@Observable
final class AuthStateObserver {
    private(set) var userID: String?
    /// Firebase delivers auth callbacks off the main actor; only touched from init/deinit.
    @ObservationIgnored
    private nonisolated(unsafe) var listener: AuthStateDidChangeListenerHandle?

    var isSignedIn: Bool { userID != nil }

    init() {
        userID = Auth.auth().currentUser?.uid
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.userID = user?.uid
            }
        }
    }

    deinit {
        if let listener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
}
