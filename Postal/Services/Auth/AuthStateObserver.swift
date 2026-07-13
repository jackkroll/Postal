import FirebaseAuth
import Observation

@Observable
final class AuthStateObserver {
    private(set) var isSignedIn: Bool
    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        isSignedIn = Auth.auth().currentUser != nil
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isSignedIn = user != nil
        }
    }

    deinit {
        if let listener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
}
