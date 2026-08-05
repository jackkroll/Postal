import Foundation

protocol AuthProviding: AnyObject, TokenProviding {
    var currentUserID: String? { get }
    var isSignedIn: Bool { get }

    func signInWithApple(
        idToken: String,
        rawNonce: String
    ) async throws
    /// Temporary: signs into an existing email/password account only (no signup).
    func signIn(email: String, password: String) async throws
    func signOut() throws
}
