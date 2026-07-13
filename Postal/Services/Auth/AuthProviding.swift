import Foundation

protocol AuthProviding: AnyObject, TokenProviding {
    var currentUserID: String? { get }
    var isSignedIn: Bool { get }

    func signIn(email: String, password: String) async throws
    func signOut() throws
}
