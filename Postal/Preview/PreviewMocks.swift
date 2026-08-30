import Foundation
import UserNotifications

final class PreviewLetterContentService: LetterContentProviding {
    var contentByShipmentID: [String: LetterContent] = [
        PreviewData.deliveredTrackingNumber: .text(PreviewData.sampleLetterText, mimeType: "text/plain"),
        PreviewData.inTransitTrackingNumber: .text(PreviewData.sampleLetterText, mimeType: "text/plain"),
        "inbound-delivered": .text(PreviewData.sampleLetterText, mimeType: "text/plain"),
    ]

    func fetchLetter(shipmentID: String, expectedFormat: LetterFormat?) async throws -> LetterContent {
        if let content = contentByShipmentID[shipmentID] {
            return content
        }
        throw APIError.httpStatus(403, "Letter access denied")
    }

    func probeLetter(shipmentID: String) async throws -> LetterProbe {
        LetterProbe(contentType: "application/json", contentLength: PreviewData.sampleLetterText.utf8.count)
    }
}

// MARK: - Services

final class PreviewAuthService: AuthProviding {
    var currentUserID: String? = "preview-user-id"
    var isSignedIn: Bool = true

    func signInWithApple(
        idToken: String,
        rawNonce: String
    ) async throws {}
    func signIn(email: String, password: String) async throws {}
    func signOut() throws {}
    func idToken(forceRefresh: Bool) async throws -> String? { "preview-token" }
}

@Observable
final class PreviewEntitlementsService: EntitlementsProviding {
    var entitlements: UserEntitlements?

    func refresh() async {}

    func refreshAfterPurchase() async {}

    func claimStampAllowance() async throws -> StampAllowanceClaimResponse {
        StampAllowanceClaimResponse(credited: 5, stampBalance: 5, nextClaimAt: nil)
    }

    func clear() {
        entitlements = nil
    }
}

extension UserEntitlements {
    static let previewFree = UserEntitlements(
        isSubscriber: false,
        expiresAt: nil,
        stampBalance: 3,
        stampPricing: .default,
        unlimitedSends: false,
        mailboxLimit: 1,
        ownedMailboxes: 1,
        letter: LetterLimitBlock(
            textMaxBytes: 4_096,
            drawingMaxBytes: 20_480,
            subscriber: LetterSizeCaps(textMaxBytes: 12_288, drawingMaxBytes: 61_440)
        ),
        allowance: StampAllowanceInfo(
            amount: 5,
            intervalSeconds: 604_800,
            claimable: true,
            lastClaimedAt: nil,
            nextClaimAt: nil,
            availableWhileSubscribed: false
        ),
        notification: NotificationEntitlements(
            allowedSent: [SentNotificationMode.destinationOnly.rawValue],
            allowedInbound: [InboundNotificationMode.arrivalOnly.rawValue],
            defaultSent: SentNotificationMode.destinationOnly.rawValue,
            defaultInbound: InboundNotificationMode.arrivalOnly.rawValue
        )
    )
}

// MARK: - View Model Factories

extension LettersListView.ViewModel {
    static func preview(
        letters: [LetterSummary] = PreviewData.letters,
        inboundLetters: [LetterSummary] = [],
        drafts: [LetterDraft] = [],
        openedInboundShipmentIDs: Set<String> = []
    ) -> LettersListView.ViewModel {
        let openStore = PreviewInboundLetterOpenStore(openedIDs: openedInboundShipmentIDs)
        let viewModel = LettersListView.ViewModel(
            api: APIClient(),
            inboundOpenStore: openStore
        )
        viewModel.letters = letters
        viewModel.inboundLetters = inboundLetters
        viewModel.drafts = drafts
        viewModel.hasLoadedSent = true
        viewModel.hasLoadedInbound = true
        viewModel.mailboxesByID = Dictionary(
            uniqueKeysWithValues: PreviewData.allMailboxes.map { ($0.id, $0) }
        )
        viewModel.locationsByCode = PreviewData.locationsByCode
        return viewModel
    }
}

final class PreviewInboundLetterOpenStore: InboundLetterOpenStoring {
    private var openedIDs: Set<String>

    init(openedIDs: Set<String> = []) {
        self.openedIDs = openedIDs
    }

    func hasOpened(_ shipmentID: String) -> Bool {
        openedIDs.contains(shipmentID)
    }

    func markOpened(_ shipmentID: String) {
        openedIDs.insert(shipmentID)
    }

    func prune(keeping shipmentIDs: Set<String>) {
        openedIDs = openedIDs.intersection(shipmentIDs)
    }
}

extension TrackingView.ViewModel {
    static func preview(
        trackingNumber: String = "",
        route: TrackingRoute? = nil,
        trackingInfo: TrackingInfo? = nil,
        letterSummary: LetterSummary? = nil,
        isRecipient: Bool = false,
        openedInboundShipmentIDs: Set<String> = [],
        errorMessage: String? = nil,
        isLoading: Bool = false
    ) -> TrackingView.ViewModel {
        let viewModel = TrackingView.ViewModel(
            apiClient: APIClient(),
            letterService: PreviewLetterContentService(),
            letterSummary: letterSummary,
            isRecipient: isRecipient,
            inboundOpenStore: PreviewInboundLetterOpenStore(openedIDs: openedInboundShipmentIDs),
            autoLookup: false
        )
        viewModel.trackingNumber = trackingNumber
        viewModel.trackingRoute = route
        viewModel.trackingInfo = trackingInfo
        viewModel.locationsByCode = PreviewData.locationsByCode
        viewModel.errorMessage = errorMessage
        viewModel.isLoading = isLoading
        return viewModel
    }
}

extension SignInView.ViewModel {
    static func preview(
        errorMessage: String? = nil,
        isLoading: Bool = false,
        isSignedIn: Bool = false
    ) -> SignInView.ViewModel {
        let auth = PreviewAuthService()
        auth.isSignedIn = isSignedIn
        auth.currentUserID = isSignedIn ? "preview-user-id" : nil

        let viewModel = SignInView.ViewModel(auth: auth)
        viewModel.errorMessage = errorMessage
        viewModel.isLoading = isLoading
        return viewModel
    }
}

extension ShipLetterView.ViewModel {
    static func preview(
        ownedMailboxes: [MailboxSummary] = PreviewData.ownedMailboxes,
        selectedOriginMailbox: MailboxSummary? = nil,
        selectedDestinationMailbox: MailboxSummary? = nil,
        letterText: String = "",
        errorMessage: String? = nil,
        isSending: Bool = false
    ) -> ShipLetterView.ViewModel {
        let viewModel = ShipLetterView.ViewModel(api: APIClient())
        viewModel.ownedMailboxes = ownedMailboxes
        viewModel.selectedOriginMailboxID = selectedOriginMailbox?.id
        viewModel.selectedDestinationMailbox = selectedDestinationMailbox
        viewModel.errorMessage = errorMessage
        return viewModel
    }
}

extension LetterCreationView.ViewModel {
    static func preview(
        phase: LetterCreationPhase = .destination,
        ownedMailboxes: [MailboxSummary] = PreviewData.ownedMailboxes,
        selectedOriginMailbox: MailboxSummary? = nil,
        selectedDestinationMailbox: MailboxSummary? = nil,
        letterText: String = "",
        composeKind: LetterComposeKind? = nil,
        isStampApplied: Bool = false,
        isSending: Bool = false
    ) -> LetterCreationView.ViewModel {
        let viewModel = LetterCreationView.ViewModel(api: APIClient())
        viewModel.phase = phase
        viewModel.envelopeVisible = true
        viewModel.letterPlacement = phase == .letterType ? .revealed : .tucked
        viewModel.ownedMailboxes = ownedMailboxes
        viewModel.selectedOriginMailboxID = selectedOriginMailbox?.id
        viewModel.selectedDestinationMailbox = selectedDestinationMailbox
        viewModel.letterText = letterText
        viewModel.recomputeLetterMetrics(from: letterText)
        viewModel.composeKind = composeKind ?? (letterText.isEmpty ? nil : .text)
        viewModel.isStampApplied = isStampApplied
        viewModel.isSending = isSending
        return viewModel
    }
}

extension ComposeView.ViewModel {
    static func preview(
        source: MailboxSummary = PreviewData.ownedMailboxes[0],
        destination: MailboxSummary = PreviewData.destinationMailboxes[0],
        letterText: String = "",
        isSending: Bool = false
    ) -> ComposeView.ViewModel {
        let viewModel = ComposeView.ViewModel(
            api: APIClient(),
            source: source,
            destination: destination,
            limits: .preview
        )
        viewModel.letterText = letterText
        viewModel.isSending = isSending
        return viewModel
    }
}

extension ClaimMailboxView.ViewModel {
    static func preview(
        postOffices: [PostOffice] = PreviewData.postOffices,
        selectedPostOffice: PostOffice? = nil,
        searchText: String = "",
        errorMessage: String? = nil,
        isClaiming: Bool = false,
        hasLoadedPostOffices: Bool = true
    ) -> ClaimMailboxView.ViewModel {
        let viewModel = ClaimMailboxView.ViewModel(api: APIClient())
        viewModel.postOffices = postOffices
        viewModel.selectedPostOffice = selectedPostOffice
        viewModel.searchText = searchText
        viewModel.errorMessage = errorMessage
        viewModel.isClaiming = isClaiming
        viewModel.hasLoadedPostOffices = hasLoadedPostOffices
        return viewModel
    }
}

extension SettingsView.ViewModel {
    static func preview(
        userEntitlements: UserEntitlements = .previewFree,
        authorizationStatus: UNAuthorizationStatus = .notDetermined,
        registeredSummary: DeviceTokenSummary? = nil,
        errorMessage: String? = nil,
        isRegistering: Bool = false,
        isDisabling: Bool = false,
        isClaimingAllowance: Bool = false,
        sentMode: SentNotificationMode? = nil,
        inboundMode: InboundNotificationMode? = nil,
        allowedSentModes: [SentNotificationMode]? = nil,
        allowedInboundModes: [InboundNotificationMode]? = nil
    ) -> SettingsView.ViewModel {
        let push = PreviewPushNotificationService(authorizationStatus: authorizationStatus)
        let entitlementsService = PreviewEntitlementsService()
        entitlementsService.entitlements = userEntitlements
        let viewModel = SettingsView.ViewModel(
            api: APIClient(),
            auth: PreviewAuthService(),
            push: push,
            entitlementsService: entitlementsService
        )
        viewModel.authorizationStatus = authorizationStatus
        viewModel.registeredSummary = registeredSummary
        viewModel.errorMessage = errorMessage
        viewModel.isRegistering = isRegistering
        viewModel.isDisabling = isDisabling
        viewModel.isClaimingAllowance = isClaimingAllowance
        viewModel.showSuccess = registeredSummary != nil
        viewModel.sentMode = sentMode ?? userEntitlements.notification.allowedSentModes.first ?? .destinationOnly
        viewModel.inboundMode = inboundMode ?? userEntitlements.notification.allowedInboundModes.first ?? .arrivalOnly
        viewModel.allowedSentModes = allowedSentModes ?? userEntitlements.notification.allowedSentModes
        viewModel.allowedInboundModes = allowedInboundModes ?? userEntitlements.notification.allowedInboundModes
        return viewModel
    }
}

extension AddressBook.ViewModel {
    static func preview(
        addresses: [AddressBookEntrySummary] = PreviewData.addressBookEntries,
        ownedMailboxes: [MailboxSummary] = PreviewData.ownedMailboxes
    ) -> AddressBook.ViewModel {
        let viewModel = AddressBook.ViewModel(api: APIClient())
        viewModel.addresses = addresses
        viewModel.ownedMailboxes = ownedMailboxes
        viewModel.hasLoadedOwned = true
        viewModel.hasLoadedAddresses = true
        return viewModel
    }
}

final class PreviewPushNotificationService: PushNotificationsProviding {
    var currentDeviceToken: String? = "preview-device-token"
    var authorizationStatus: UNAuthorizationStatus
    var appInstanceID = "preview-app-instance"

    init(authorizationStatus: UNAuthorizationStatus = .notDetermined) {
        self.authorizationStatus = authorizationStatus
    }

    func refreshAuthorizationStatus() async {}

    func registerIfAuthorized() async {}

    func deviceTokenIfAuthorized() async throws -> String? {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return currentDeviceToken ?? "preview-device-token"
        default:
            return nil
        }
    }

    func requestAuthorizationAndToken() async throws -> String {
        authorizationStatus = .authorized
        let token = currentDeviceToken ?? "preview-device-token"
        currentDeviceToken = token
        return token
    }

    func handleDeviceToken(_ deviceToken: Data) {}
    func handleRegistrationFailure(_ error: Error) {}

    func clearLocalRegistration(userOptedOut: Bool) {
        currentDeviceToken = nil
    }

    func clearAppIconBadge() async {}
}

// MARK: - Onboarding

extension OnboardingStore {
    static func preview(
        step: OnboardingStep = .claimMailbox,
        status: OnboardingStatus = .inProgress,
        origin: MailboxSummary? = PreviewData.ownedMailboxes.first,
        savedDestination: MailboxSummary? = nil,
        savedDestinationNickname: String? = nil,
        pendingTimeCapsuleID: UUID? = nil
    ) -> OnboardingStore {
        let suiteName = "postal.onboarding.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let store = OnboardingStore(defaults: defaults)
        store.load(userID: "preview-user-id")

        var progress = OnboardingProgress.fresh(startingAt: step)
        progress.status = status
        if let origin {
            progress.originMailboxID = origin.id
            progress.originMailboxLabel = origin.label
        }
        progress.savedDestination = savedDestination
        progress.savedDestinationNickname = savedDestinationNickname
        progress.pendingTimeCapsuleID = pendingTimeCapsuleID
        store.replaceProgress(progress)
        return store
    }
}

final class PreviewPendingTimeCapsuleStore: PendingTimeCapsuleStoring {
    var capsules: [PendingTimeCapsule] = []

    func list() -> [PendingTimeCapsule] { capsules.sorted { $0.createdAt > $1.createdAt } }

    func load(id: UUID) -> PendingTimeCapsule? {
        capsules.first { $0.id == id }
    }

    func save(_ capsule: PendingTimeCapsule) {
        capsules.removeAll { $0.id == capsule.id }
        capsules.append(capsule)
    }

    func delete(id: UUID) {
        capsules.removeAll { $0.id == id }
    }
}

extension UserEntitlements {
    static let previewPlus = UserEntitlements(
        isSubscriber: true,
        expiresAt: "2025-12-31T00:00:00Z",
        stampBalance: 42,
        stampPricing: .default,
        unlimitedSends: true,
        mailboxLimit: 5,
        ownedMailboxes: 2,
        letter: LetterLimitBlock(
            textMaxBytes: 12_288,
            drawingMaxBytes: 61_440,
            subscriber: LetterSizeCaps(textMaxBytes: 12_288, drawingMaxBytes: 61_440)
        ),
        allowance: StampAllowanceInfo(
            amount: 5,
            intervalSeconds: 604_800,
            claimable: false,
            lastClaimedAt: nil,
            nextClaimAt: nil,
            availableWhileSubscribed: false
        ),
        notification: NotificationEntitlements(
            allowedSent: SentNotificationMode.allCases.map(\.rawValue),
            allowedInbound: InboundNotificationMode.allCases.map(\.rawValue),
            defaultSent: SentNotificationMode.shipmentDetails.rawValue,
            defaultInbound: InboundNotificationMode.shipmentDetails.rawValue
        )
    )
}

extension DeviceTokenSummary {
    static let preview = DeviceTokenSummary(
        token: "preview-device-token",
        platform: "ios",
        appInstanceID: "preview-app-instance",
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

extension UserEntitlements {
    static let previewFreeAllowanceClaimed = UserEntitlements(
        isSubscriber: false,
        expiresAt: nil,
        stampBalance: 5,
        stampPricing: .default,
        unlimitedSends: false,
        mailboxLimit: 1,
        ownedMailboxes: 1,
        letter: LetterLimitBlock(
            textMaxBytes: 4_096,
            drawingMaxBytes: 20_480,
            subscriber: LetterSizeCaps(textMaxBytes: 12_288, drawingMaxBytes: 61_440)
        ),
        allowance: StampAllowanceInfo(
            amount: 5,
            intervalSeconds: 604_800,
            claimable: false,
            lastClaimedAt: "2024-07-01T12:00:00Z",
            nextClaimAt: "2024-07-05T12:00:00Z",
            availableWhileSubscribed: false
        ),
        notification: NotificationEntitlements(
            allowedSent: [SentNotificationMode.destinationOnly.rawValue],
            allowedInbound: [InboundNotificationMode.arrivalOnly.rawValue],
            defaultSent: SentNotificationMode.destinationOnly.rawValue,
            defaultInbound: InboundNotificationMode.arrivalOnly.rawValue
        )
    )
}
