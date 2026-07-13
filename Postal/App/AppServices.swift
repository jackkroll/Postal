import Foundation

/// Shared service instances. A future Coordinator layer can own and inject these.
enum AppServices {
    static let auth: AuthProviding = FirebaseAuthService()
    static let letters: LettersProviding = FirestoreLettersService()
    static let letterContent: LetterContentProviding = LetterContentService()
    static let api: APIClient = {
        let client = APIClient()
        client.setTokenProvider(auth)
        return client
    }()
}
