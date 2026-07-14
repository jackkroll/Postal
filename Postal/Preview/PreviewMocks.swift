import Foundation

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

final class PreviewLettersService: LettersProviding {
    private let letters: [LetterSummary]

    init(letters: [LetterSummary] = PreviewData.letters) {
        self.letters = letters
    }

    func startListening(userID: String, onChange: @escaping ([LetterSummary]) -> Void) -> AnyObject? {
        onChange(letters)
        return NSObject()
    }

    func stopListening(_ token: AnyObject?) {}
}

// MARK: - View Model Factories

extension LettersListView.ViewModel {
    static func preview(letters: [LetterSummary] = PreviewData.letters) -> LettersListView.ViewModel {
        let viewModel = LettersListView.ViewModel(
            auth: PreviewAuthService(),
            lettersService: PreviewLettersService(letters: letters),
            api: APIClient()
        )
        viewModel.letters = letters
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
        errorMessage: String? = nil,
        isLoading: Bool = false
    ) -> TrackingView.ViewModel {
        let viewModel = TrackingView.ViewModel(
            apiClient: APIClient(),
            letterService: PreviewLetterContentService(),
            letterSummary: letterSummary,
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
        viewModel.selectedOriginMailbox = selectedOriginMailbox
        viewModel.selectedDestinationMailbox = selectedDestinationMailbox
        viewModel.letterText = letterText
        viewModel.errorMessage = errorMessage
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
