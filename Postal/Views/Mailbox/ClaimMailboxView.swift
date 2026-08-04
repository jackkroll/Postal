import SwiftUI

struct ClaimMailboxView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewmodel: ViewModel
    @State private var isPaywallPresented = false
    private let loadsOnAppear: Bool

    init(
        viewmodel: ViewModel = ViewModel(api: AppServices.api),
        loadsOnAppear: Bool = true
    ) {
        _viewmodel = State(initialValue: viewmodel)
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        Group {
            if viewmodel.isAtMailboxLimit {
                mailboxLimitReached
            } else if let selectedPostOffice = viewmodel.selectedPostOffice {
                claimConfirmation(for: selectedPostOffice)
            } else {
                postOfficeList
            }
        }
        .navigationTitle(viewmodel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewmodel.selectedPostOffice != nil, !viewmodel.isAtMailboxLimit {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewmodel.claim() }
                    } label: {
                        Text(viewmodel.isClaiming ? "Claiming…" : "Claim")
                    }
                    .disabled(!viewmodel.canClaim)
                }
            }
        }
        .overlay {
            if viewmodel.showsLoadingOverlay {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .alert("Mailbox Claimed", isPresented: $viewmodel.showSuccess) {
            Button("Done") {
                dismiss()
            }
        } message: {
            if let mailbox = viewmodel.claimedMailbox {
                Text("\(mailbox.label)\n\(mailbox.locationLabel)")
            }
        }
        .task {
            guard loadsOnAppear else { return }
            await viewmodel.refreshEntitlements()
        }
        .task(id: viewmodel.searchText) {
            guard loadsOnAppear else { return }
            guard viewmodel.selectedPostOffice == nil, !viewmodel.isAtMailboxLimit else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await viewmodel.searchPostOffices()
        }
        .sheet(isPresented: $isPaywallPresented) {
            PlusPaywallSheet(source: .mailboxLimit) {
                Task { await viewmodel.refreshEntitlementsAfterPurchase() }
            }
        }
    }

    @ViewBuilder
    private var mailboxLimitReached: some View {
        ContentUnavailableView {
            Label(PromoText.mailboxLimitReachedTitle, systemImage: "tray.full")
        } description: {
            Text(viewmodel.mailboxLimitMessage)
        } actions: {
            if !viewmodel.isSubscriber {
                Button(PromoText.upgradeToPlus) {
                    MonetizationAnalytics.upgradeTapped(source: .mailboxLimit)
                    isPaywallPresented = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var postOfficeList: some View {
        Group {
            if let errorMessage = viewmodel.errorMessage, viewmodel.postOffices.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if viewmodel.postOffices.isEmpty, !viewmodel.isLoadingPostOffices {
                ContentUnavailableView.search(text: viewmodel.searchText)
            } else {
                List(viewmodel.postOffices) { office in
                    PostOfficeLocationRow(postOffice: office)
                }
                .listStyle(.plain)
            }
        }
        .searchable(
            text: $viewmodel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search post offices"
        )
    }

    @ViewBuilder
    private func claimConfirmation(for postOffice: PostOffice) -> some View {
        Form {
            Section {
                Text(postOffice.name)
                    .foregroundStyle(.secondary)

                Button("Choose a different post office") {
                    viewmodel.clearSelection()
                }
                .disabled(viewmodel.isClaiming)
            } header: {
                Text("Post Office")
            } footer: {
                Text(viewmodel.claimFooterText)
            }

            if viewmodel.isClaiming {
                Section {
                    HStack {
                        ProgressView()
                        Text("Claiming mailbox…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage = viewmodel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                    if viewmodel.showsUpgradeOnError {
                        Button(PromoText.upgradeToPlus) {
                            MonetizationAnalytics.upgradeTapped(source: .mailboxLimit)
                            isPaywallPresented = true
                        }
                    }
                }
            }
        }
    }
}

extension ClaimMailboxView {
    @Observable
    class ViewModel {
        let api: APIClient
        let entitlementsService: EntitlementsProviding

        var searchText = ""
        var postOffices: [PostOffice] = []
        var selectedPostOffice: PostOffice?
        var claimedMailbox: MailboxSummary?

        var isLoadingPostOffices = false
        var hasLoadedPostOffices = false
        var isClaiming = false
        var errorMessage: String?
        var showSuccess = false
        var showsUpgradeOnError = false

        var entitlements: UserEntitlements? {
            entitlementsService.entitlements
        }

        var isSubscriber: Bool {
            entitlements?.isSubscriber == true
        }

        var isAtMailboxLimit: Bool {
            guard let entitlements else { return false }
            return !entitlements.canClaimAnotherMailbox
        }

        var navigationTitle: String {
            if isAtMailboxLimit {
                return PromoText.mailboxLimitTitle
            }
            return selectedPostOffice?.name ?? "Claim Mailbox"
        }

        var mailboxLimitMessage: String {
            guard let entitlements else {
                return PromoText.mailboxLimitReachedFallback
            }
            return PromoText.mailboxLimitReached(
                owned: entitlements.ownedMailboxes,
                limit: entitlements.mailboxLimit,
                isSubscriber: isSubscriber
            )
        }

        var claimFooterText: String {
            if let entitlements {
                return PromoText.claimMailboxFooter(
                    owned: entitlements.ownedMailboxes,
                    limit: entitlements.mailboxLimit
                )
            }
            return PromoText.claimMailboxFooterFallback
        }

        var canClaim: Bool {
            guard !isAtMailboxLimit else { return false }
            guard let postOffice = selectedPostOffice else { return false }
            return PostOfficeValidation.isValidID(postOffice.id) && !isClaiming
        }

        var showsLoadingOverlay: Bool {
            isLoadingPostOffices && !hasLoadedPostOffices
        }

        init(
            api: APIClient,
            entitlementsService: EntitlementsProviding = AppServices.entitlements
        ) {
            self.api = api
            self.entitlementsService = entitlementsService
        }

        @MainActor
        func refreshEntitlements() async {
            await entitlementsService.refresh()
        }

        @MainActor
        func refreshEntitlementsAfterPurchase() async {
            await entitlementsService.refreshAfterPurchase()
        }

        func selectPostOffice(_ office: PostOffice) {
            selectedPostOffice = office
            errorMessage = nil
            showsUpgradeOnError = false
        }

        func clearSelection() {
            selectedPostOffice = nil
            errorMessage = nil
            showsUpgradeOnError = false
        }

        func searchPostOffices() async {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let isInitialLoad = !hasLoadedPostOffices
            if isInitialLoad {
                isLoadingPostOffices = true
            }
            errorMessage = nil
            defer {
                if isInitialLoad {
                    isLoadingPostOffices = false
                }
            }

            do {
                postOffices = try await api.listPostOffices(
                    search: query.isEmpty ? nil : query,
                    limit: 100
                )
                hasLoadedPostOffices = true
            } catch {
                postOffices = []
                errorMessage = error.localizedDescription
                hasLoadedPostOffices = true
            }
        }

        func claim() async {
            guard let postOffice = selectedPostOffice else { return }
            guard PostOfficeValidation.isValidID(postOffice.id) else {
                errorMessage = MailboxLookupError.invalidPostOfficeID(postOffice.id).localizedDescription
                return
            }
            guard !isAtMailboxLimit else {
                errorMessage = mailboxLimitMessage
                showsUpgradeOnError = !isSubscriber
                return
            }

            isClaiming = true
            errorMessage = nil
            showsUpgradeOnError = false
            defer { isClaiming = false }

            do {
                let mailbox = try await api.claimMailbox(postOfficeID: postOffice.id)
                claimedMailbox = mailbox
                if let service = entitlementsService as? EntitlementsService {
                    await MainActor.run { service.applyLocalMailboxClaim() }
                }
                await entitlementsService.refresh()
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                if case let APIError.httpStatus(code, _, _) = error, code == 429 {
                    showsUpgradeOnError = !isSubscriber
                    await entitlementsService.refresh()
                }
            }
        }
    }
}

#Preview("Post Offices") {
    NavigationStack {
        ClaimMailboxView(viewmodel: .preview(), loadsOnAppear: false)
    }
}

#Preview("Confirm") {
    NavigationStack {
        ClaimMailboxView(viewmodel: .preview(
            postOffices: PreviewData.postOffices,
            selectedPostOffice: PreviewData.mainStreetPostOffice,
            hasLoadedPostOffices: true
        ), loadsOnAppear: false)
    }
}
