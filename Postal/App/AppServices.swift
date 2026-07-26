import Foundation

/// Shared service instances. A future Coordinator layer can own and inject these.
enum AppServices {
    static let auth: AuthProviding = FirebaseAuthService()
    static let letterContent: LetterContentProviding = LetterContentService()
    static let letterDrafts: DraftLetterStoring = DraftLetterStore()
    static let letterLimits: LetterLimitsProviding = LetterLimitsService()
    static let pushNotifications: PushNotificationsProviding = PushNotificationService.shared
    static let api: APIClient = {
        let client = APIClient()
        client.setTokenProvider(auth)
        return client
    }()
    static let entitlements: EntitlementsService = EntitlementsService(api: api)
    static let purchasesIdentity = PurchasesIdentityService()
}
