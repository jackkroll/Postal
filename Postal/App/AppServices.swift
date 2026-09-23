import Foundation

/// Shared service instances. A future Coordinator layer can own and inject these.
enum AppServices {
    static let auth: AuthProviding = FirebaseAuthService()
    static let letterContent: LetterContentProviding = LetterContentService()
    static let letterDrafts: DraftLetterStoring = DraftLetterStore()
    static let inboundLetterOpens: InboundLetterOpenStoring = InboundLetterOpenStore.shared
    static let pendingTimeCapsules: PendingTimeCapsuleStoring = PendingTimeCapsuleStore()
    static let pendingMailboxInvites = PendingMailboxInviteStore()
    static let onboarding = OnboardingStore()
    static let pushNotifications: PushNotificationsProviding = PushNotificationService.shared
    static let api: APIClient = {
        let client = APIClient()
        client.setTokenProvider(auth)
        return client
    }()
    static let entitlements: EntitlementsService = EntitlementsService(api: api)
    static let blocks: BlockService = BlockService(api: api)
    static let reports: ReportService = ReportService(api: api)
    static let purchasesIdentity = PurchasesIdentityService()
}
