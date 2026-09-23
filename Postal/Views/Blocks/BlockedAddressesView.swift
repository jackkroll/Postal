import SwiftUI

struct BlockedAddressesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewmodel: ViewModel
    /// Presented as a sheet from the composer; needs its own dismissal control.
    private let presentedModally: Bool
    private let loadsOnAppear: Bool

    init(
        viewmodel: ViewModel,
        presentedModally: Bool = false,
        loadsOnAppear: Bool = true
    ) {
        _viewmodel = State(initialValue: viewmodel)
        self.presentedModally = presentedModally
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        List {
            if let errorMessage = viewmodel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            blockedSection
        }
        .navigationTitle(BlockText.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentedModally {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) { dismiss() }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    viewmodel.isPickerPresented = true
                } label: {
                    Label(BlockText.addAction, systemImage: "plus")
                }
            }
        }
        .refreshable {
            await viewmodel.refresh()
        }
        .sheet(isPresented: $viewmodel.isPickerPresented, onDismiss: {
            // The picker dismisses itself on selection; wait it out before the
            // confirmation sheet, or the second presentation is dropped.
            viewmodel.presentChosenTarget()
        }) {
            DestinationMailboxPickerSheet(
                api: viewmodel.api,
                title: BlockText.chooseAddressTitle
            ) { mailbox in
                viewmodel.selectTarget(mailbox)
            }
        }
        .moderationFlow(viewmodel.moderation)
        .alert(
            BlockText.unblockTitle,
            isPresented: Binding(
                get: { viewmodel.unblockCandidate != nil },
                set: { if !$0 { viewmodel.unblockCandidate = nil } }
            ),
            presenting: viewmodel.unblockCandidate
        ) { candidate in
            Button("Cancel", role: .cancel) { viewmodel.unblockCandidate = nil }
            Button(BlockText.unblockAction, role: .destructive) {
                Task { await viewmodel.unblock(candidate) }
            }
        } message: { _ in
            Text(BlockText.unblockBody)
        }
        .task {
            guard loadsOnAppear else { return }
            await viewmodel.refresh()
        }
    }

    @ViewBuilder
    private var blockedSection: some View {
        Section {
            if let failure = viewmodel.loadFailure, viewmodel.blockedAddresses.isEmpty {
                ContentUnavailableView {
                    Label(failure.title(resource: "Blocks"), systemImage: failure.systemImage)
                } description: {
                    Text(failure.message)
                } actions: {
                    Button("Try Again") {
                        Task { await viewmodel.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !viewmodel.hasLoaded, viewmodel.blockedAddresses.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading blocked addresses…")
                        .foregroundStyle(.secondary)
                }
            } else if viewmodel.blockedAddresses.isEmpty {
                ContentUnavailableView {
                    Label(BlockText.emptyTitle, systemImage: "hand.raised")
                } description: {
                    Text(BlockText.emptyBody)
                } actions: {
                    Button(BlockText.addAction) {
                        viewmodel.isPickerPresented = true
                    }
                }
            } else {
                ForEach(viewmodel.blockedAddresses) { block in
                    BlockedAddressRow(block: block)
                        .swipeActions(edge: .trailing) {
                            Button(BlockText.unblockAction) {
                                viewmodel.unblockCandidate = block
                            }
                            .tint(.blue)
                        }
                }
            }
        } footer: {
            if !viewmodel.blockedAddresses.isEmpty {
                Text(BlockText.listFooter)
            }
        }
    }
}

struct BlockedAddressRow: View {
    let block: BlockedAddress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(block.displayLabel)
                .font(.body.weight(.semibold))
            HStack(spacing: 6) {
                Text(block.locationLabel)
                Text(block.mailboxID)
                    .font(.caption.monospaced())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(BlockText.blockedOn(block.createdAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
            if block.isMailboxReleased {
                Text(BlockText.releasedMailbox)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

extension BlockedAddressesView {
    @Observable
    class ViewModel {
        let api: APIClient
        let blocks: BlockService
        let reports: ReportService
        let moderation: ModerationFlow

        /// Kept in sync with the flow so a self-block is caught before a round trip.
        var ownedMailboxes: [MailboxSummary] = [] {
            didSet { moderation.ownedMailboxIDs = Set(ownedMailboxes.map(\.id)) }
        }
        var isPickerPresented = false
        /// Chosen in the picker, held until that sheet finishes dismissing.
        private var chosenTarget: MailboxSummary?
        var errorMessage: String?
        var unblockCandidate: BlockedAddress?

        init(
            api: APIClient,
            blocks: BlockService = AppServices.blocks,
            reports: ReportService = AppServices.reports
        ) {
            self.api = api
            self.blocks = blocks
            self.reports = reports
            moderation = ModerationFlow(reports: reports, blocks: blocks)
        }

        var blockedAddresses: [BlockedAddress] { blocks.blocks }
        var hasLoaded: Bool { blocks.hasLoaded }
        var loadFailure: PostalLoadFailure? { blocks.loadFailure }

        @MainActor
        func refresh() async {
            async let blocksFetch: Void = blocks.load()
            async let ownedFetch: Void = loadOwnedMailboxes()
            // Reports are only read here so the follow-up offer after a block knows
            // whether this address has already been reported.
            async let reportsFetch: Void = reports.load()
            _ = await (blocksFetch, ownedFetch, reportsFetch)
        }

        /// Own mailboxes are fetched so the self-block 400 can be pre-empted.
        @MainActor
        func loadOwnedMailboxes() async {
            do {
                ownedMailboxes = try await api.listOwnedMailboxes()
            } catch {
                // Non-fatal: the server still rejects a self-block.
            }
        }

        @MainActor
        func selectTarget(_ mailbox: MailboxSummary) {
            errorMessage = nil
            chosenTarget = mailbox
        }

        @MainActor
        func presentChosenTarget() {
            guard let chosenTarget else { return }
            self.chosenTarget = nil
            moderation.beginBlock(chosenTarget)
        }

        @MainActor
        func unblock(_ block: BlockedAddress) async {
            unblockCandidate = nil
            errorMessage = nil

            do {
                try await blocks.unblock(id: block.id)
            } catch {
                guard !error.isPostalCancellation else { return }
                errorMessage = BlockService.unblockFailureMessage(error)
            }
        }
    }
}

#Preview("Blocked") {
    NavigationStack {
        BlockedAddressesView(viewmodel: .preview(), loadsOnAppear: false)
    }
}

#Preview("Empty") {
    NavigationStack {
        BlockedAddressesView(viewmodel: .preview(blocks: []), loadsOnAppear: false)
    }
}
