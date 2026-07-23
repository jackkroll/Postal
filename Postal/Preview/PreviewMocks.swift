import Foundation
import UserNotifications

final class PreviewLetterContentService: LetterContentProviding {
    var contentByShipmentID: [String: LetterContent] = [
        PreviewData.deliveredTrackingNumber: .text(PreviewData.sampleLetterText, mimeType: "text/plain"),
        PreviewData.inTransitTrackingNumber: .text(PreviewData.sampleLetterText, mimeType: "text/plain"),
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

    func signIn(email: String, password: String) async throws {}
    func signOut() throws {}
    func idToken(forceRefresh: Bool) async throws -> String? { "preview-token" }
}

// MARK: - View Model Factories

extension LettersListView.ViewModel {
    static func preview(
        letters: [LetterSummary] = PreviewData.letters,
        inboundLetters: [InboundLetterItem] = []
    ) -> LettersListView.ViewModel {
        let viewModel = LettersListView.ViewModel(api: APIClient())
        viewModel.letters = letters
        viewModel.inboundLetters = inboundLetters
        viewModel.mailboxesByID = Dictionary(
            uniqueKeysWithValues: PreviewData.allMailboxes.map { ($0.id, $0) }
        )
        viewModel.locationsByCode = [
            PreviewData.mainStreetLocation.code: PreviewData.mainStreetLocation,
            PreviewData.westsideLocation.code: PreviewData.westsideLocation,
            PreviewData.riversideLocation.code: PreviewData.riversideLocation,
        ]
        return viewModel
    }
}

extension TrackingView.ViewModel {
    static func preview(
        trackingNumber: String = "",
        route: TrackingRoute? = nil,
        letterSummary: LetterSummary? = nil,
        isRecipient: Bool = false,
        errorMessage: String? = nil,
        isLoading: Bool = false
    ) -> TrackingView.ViewModel {
        let viewModel = TrackingView.ViewModel(
            apiClient: APIClient(),
            letterService: PreviewLetterContentService(),
            letterSummary: letterSummary,
            isRecipient: isRecipient,
            autoLookup: false
        )
        viewModel.trackingNumber = trackingNumber
        viewModel.trackingRoute = route
        viewModel.errorMessage = errorMessage
        viewModel.isLoading = isLoading
        return viewModel
    }
}

extension SignInView.ViewModel {
    static func preview(
        email: String = "",
        password: String = "",
        errorMessage: String? = nil,
        isLoading: Bool = false,
        isSignedIn: Bool = false
    ) -> SignInView.ViewModel {
        let auth = PreviewAuthService()
        auth.isSignedIn = isSignedIn
        auth.currentUserID = isSignedIn ? "preview-user-id" : nil

        let viewModel = SignInView.ViewModel(auth: auth)
        viewModel.email = email
        viewModel.password = password
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
        viewModel.letterPlacement = phase == .compose ? .revealed : .tucked
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
            destination: destination
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
        authorizationStatus: UNAuthorizationStatus = .notDetermined,
        registeredSummary: DeviceTokenSummary? = nil,
        errorMessage: String? = nil,
        isRegistering: Bool = false,
        sentMode: SentNotificationMode = .shipmentDetails,
        inboundMode: InboundNotificationMode = .shipmentDetails
    ) -> SettingsView.ViewModel {
        let push = PreviewPushNotificationService(authorizationStatus: authorizationStatus)
        let viewModel = SettingsView.ViewModel(api: APIClient(), auth: PreviewAuthService(), push: push)
        viewModel.authorizationStatus = authorizationStatus
        viewModel.registeredSummary = registeredSummary
        viewModel.errorMessage = errorMessage
        viewModel.isRegistering = isRegistering
        viewModel.showSuccess = registeredSummary != nil
        viewModel.sentMode = sentMode
        viewModel.inboundMode = inboundMode
        return viewModel
    }
}

extension AddressBook.ViewModel {
    static func preview(
        addresses: [AddressBookEntrySummary] = PreviewData.addressBookEntries
    ) -> AddressBook.ViewModel {
        let viewModel = AddressBook.ViewModel(api: APIClient())
        viewModel.addresses = addresses
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
}
