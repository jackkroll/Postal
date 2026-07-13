import FirebaseAuth
import Foundation

final class FirebaseAuthService: AuthProviding {
    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    var isSignedIn: Bool {
        currentUserID != nil
    }

    func idToken(forceRefresh: Bool) async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await user.getIDTokenResult(forcingRefresh: forceRefresh).token
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
