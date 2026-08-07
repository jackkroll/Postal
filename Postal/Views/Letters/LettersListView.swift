import SwiftUI

struct LettersListView: View {
    private enum LettersTab: String, CaseIterable, Identifiable {
        case sent
        case inbound

        var id: String { rawValue }

        var title: String {
            switch self {
            case .sent: "Sent"
            case .inbound: "Inbound"
            }
        }
    }

    @AppStorage(AppStorageKeys.showInboundLetters) private var showInboundLetters = true
    @State private var selectedTab: LettersTab = .sent
    @State private var viewmodel: ViewModel
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
            if showInboundLetters {
                tabbedContent
            } else {
                sentContent
            }
        }
        .navigationTitle("My Letters")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                NavigationLink(value: ViewRoute.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                NavigationLink(value: ViewRoute.addressbook) {
                    Label("Address Book", systemImage: "book")
                }
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
            ToolbarItem(placement: .bottomBar) {
                NavigationLink(value: ViewRoute.ship()) {
                    Label("Ship", systemImage: "square.and.pencil")
                }
            }
        }
        .onChange(of: showInboundLetters) { _, isEnabled in
            if !isEnabled {
                selectedTab = .sent
            }
        }
        .onChange(of: selectedTab) { _, tab in
            guard loadsOnAppear else { return }
            Task {
                switch tab {
                case .sent:
                    await viewmodel.loadSentLetters()
                    viewmodel.loadDrafts()
                case .inbound:
                    await viewmodel.loadInboundLetters()
                }
            }
        }
        .task {
            guard loadsOnAppear else { return }
            viewmodel.loadDrafts()
            await viewmodel.loadSentLetters()
            if showInboundLetters, selectedTab == .inbound {
                await viewmodel.loadInboundLetters()
            }
        }
        .task(id: showInboundLetters) {
            guard loadsOnAppear else { return }
            if showInboundLetters, selectedTab == .inbound {
                await viewmodel.loadInboundLetters()
            }
        }
        .onAppear {
            viewmodel.loadDrafts()
        }
    }

    private var tabbedContent: some View {
        VStack(spacing: 0) {
            Picker("Letters", selection: $selectedTab) {
                ForEach(LettersTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                switch selectedTab {
                case .sent:
                    sentContent
                case .inbound:
                    inboundContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var sentContent: some View {
        if viewmodel.shouldShowSentLoading {
            ProgressView("Loading letters…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let failure = viewmodel.sentLoadFailure, viewmodel.letters.isEmpty, viewmodel.drafts.isEmpty {
            sentFailureView(failure)
        } else if viewmodel.hasLoadedSent, viewmodel.letters.isEmpty, viewmodel.drafts.isEmpty {
            ContentUnavailableView {
                Label("No Letters Yet", systemImage: "envelope.open")
            } description: {
                Text("Shipments you create will appear here.")
            } actions: {
                NavigationLink("Ship a Letter", value: ViewRoute.ship())
                    .buttonStyle(.borderedProminent)
            }
        } else {
            List {
                if let failure = viewmodel.sentLoadFailure, viewmodel.letters.isEmpty {
                    Section {
                        Label(failure.title(resource: "Letters"), systemImage: failure.systemImage)
                            .foregroundStyle(.primary)
                        Text(failure.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            Task { await viewmodel.loadSentLetters() }
                        }
                    }
                }

                if !viewmodel.drafts.isEmpty {
                    Section("Drafts") {
                        ForEach(viewmodel.drafts) { draft in
                            NavigationLink(value: ViewRoute.ship(draftID: draft.id)) {
                                DraftLetterRowView(draft: draft)
                            }
                        }
                        .onDelete { indexSet in
                            viewmodel.deleteDrafts(at: indexSet)
                        }
                    }

                    Section("Sent") {
                        if viewmodel.letters.isEmpty, viewmodel.sentLoadFailure == nil {
                            Text("No sent letters yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewmodel.letters) { letter in
                                NavigationLink(value: ViewRoute.track(trackingNum: letter.trackingNumber, letter: letter)) {
                                    LetterRowView(
                                        letter: letter,
                                        origin: viewmodel.resolved(letter.origin),
                                        destination: viewmodel.resolved(letter.destination)
                                    )
                                }
                            }
                        }
                    }
                } else {
                    ForEach(viewmodel.letters) { letter in
                        NavigationLink(value: ViewRoute.track(trackingNum: letter.trackingNumber, letter: letter)) {
                            LetterRowView(
                                letter: letter,
                                origin: viewmodel.resolved(letter.origin),
                                destination: viewmodel.resolved(letter.destination)
                            )
                        }
                    }
                }
            }
            .refreshable {
                viewmodel.loadDrafts()
                await viewmodel.loadSentLetters()
            }
            .overlay(alignment: .top) {
                if viewmodel.isLoadingSent {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var inboundContent: some View {
        if viewmodel.shouldShowInboundLoading {
            ProgressView("Loading inbound letters…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let failure = viewmodel.inboundLoadFailure, viewmodel.inboundLetters.isEmpty {
            inboundFailureView(failure)
        } else if viewmodel.hasLoadedInbound, viewmodel.inboundLetters.isEmpty {
            ContentUnavailableView {
                Label("No Inbound Letters", systemImage: "tray")
            } description: {
                Text("Letters shipping to your mailboxes will appear here.")
            }
        } else {
            List {
                ForEach(viewmodel.inboundLetters) { letter in
                    NavigationLink(value: ViewRoute.track(
                        trackingNum: letter.trackingNumber,
                        letter: letter,
                        isRecipient: true
                    )) {
                        LetterRowView(
                            letter: letter,
                            origin: viewmodel.resolved(letter.origin),
                            destination: viewmodel.resolved(letter.destination)
                        )
                    }
                }
            }
            .refreshable {
                await viewmodel.loadInboundLetters()
            }
            .overlay(alignment: .top) {
                if viewmodel.isLoadingInbound {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
        }
    }

    private func sentFailureView(_ failure: PostalLoadFailure) -> some View {
        ContentUnavailableView {
            Label(failure.title(resource: "Letters"), systemImage: failure.systemImage)
        } description: {
            Text(failure.message)
        } actions: {
            Button("Try Again") {
                Task { await viewmodel.loadSentLetters() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func inboundFailureView(_ failure: PostalLoadFailure) -> some View {
        ContentUnavailableView {
            Label(failure.title(resource: "Inbound"), systemImage: failure.systemImage)
        } description: {
            Text(failure.message)
        } actions: {
            Button("Try Again") {
                Task { await viewmodel.loadInboundLetters() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct DraftLetterRowView: View {
    let draft: LetterDraft

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 40, maxHeight: 40)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.destinationTitle)
                    .font(.headline)
                    .lineLimit(1)

                if let locationName = draft.destination?.locationLabel {
                    Text(locationName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text("Draft")
                        .foregroundStyle(.orange)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(draft.updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                        .foregroundStyle(.secondary)

                    if let formatHint = draft.formatHint {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(formatHint)
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct LetterRowView: View {
    let letter: LetterSummary
    let origin: ResolvedLetterEndpoint
    let destination: ResolvedLetterEndpoint
    @State private var showTrackingCopiedAlert = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: letter.status.iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(letter.status.tintColor)
                .frame(maxWidth: 40, maxHeight: 40)
                .background(letter.status.tintColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.title)
                    .font(.headline)
                    .lineLimit(1)

                if let locationName = destination.locationName {
                    Text(locationName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("From \(origin.detailLine)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(letter.status.displayTitle)
                        .foregroundStyle(letter.status.tintColor)
                    if let arrival = letter.expectedArrivalDisplay {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(arrivalLabel(for: letter, arrival: arrival))
                            .foregroundStyle(.secondary)
                    } else if letter.status == .failed {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("ETA unavailable")
                            .foregroundStyle(.secondary)
                    } else if let updated = letter.updatedAt ?? letter.createdAt {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(updated, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = DeepLink.trackURL(for: letter.trackingNumber).absoluteString
                showTrackingCopiedAlert = true
            } label: {
                Image(systemName: "document.on.document.fill")
                Text("Copy Tracking Number")
            }
        }
        .alert("Copied", isPresented: $showTrackingCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tracking link copied to clipboard.")
        }
        .padding(.vertical, 2)
    }

    private func arrivalLabel(for letter: LetterSummary, arrival: String) -> String {
        switch letter.status {
        case .delivered:
            return "Arrived \(arrival)"
        case .held:
            return "Unlocks \(arrival)"
        default:
            return "ETA \(arrival)"
        }
    }
}

extension LettersListView {
    @Observable
    class ViewModel {
        var api: APIClient
        var draftsStore: DraftLetterStoring
        var letters: [LetterSummary] = []
        var drafts: [LetterDraft] = []
        var inboundLetters: [LetterSummary] = []
        var isLoadingSent = false
        var isLoadingInbound = false
        var hasLoadedSent = false
        var hasLoadedInbound = false
        var sentLoadFailure: PostalLoadFailure?
        var inboundLoadFailure: PostalLoadFailure?
        var mailboxesByID: [MailboxID: MailboxSummary] = [:]
        var locationsByCode: [Int: Location] = [:]

        private var resolutionTask: Task<Void, Never>?
        private var sentLoadTask: Task<Void, Never>?
        private var inboundLoadTask: Task<Void, Never>?

        init(api: APIClient, draftsStore: DraftLetterStoring = AppServices.letterDrafts) {
            self.api = api
            self.draftsStore = draftsStore
        }

        var shouldShowSentLoading: Bool {
            (isLoadingSent || !hasLoadedSent) && letters.isEmpty && drafts.isEmpty && sentLoadFailure == nil
        }

        var shouldShowInboundLoading: Bool {
            (isLoadingInbound || !hasLoadedInbound) && inboundLetters.isEmpty && inboundLoadFailure == nil
        }

        func loadDrafts() {
            drafts = draftsStore.list()
        }

        func deleteDrafts(at offsets: IndexSet) {
            for index in offsets {
                guard drafts.indices.contains(index) else { continue }
                draftsStore.delete(id: drafts[index].id)
            }
            loadDrafts()
        }

        @MainActor
        func loadSentLetters() async {
            sentLoadTask?.cancel()
            let task = Task { @MainActor in
                isLoadingSent = true
                defer { isLoadingSent = false }

                do {
                    let items = try await api.listSentLetterSummaries()
                    guard !Task.isCancelled else { return }
                    letters = items
                    sentLoadFailure = nil
                    hasLoadedSent = true
                    scheduleEndpointResolution()
                } catch {
                    guard !error.isPostalCancellation, !Task.isCancelled else { return }
                    sentLoadFailure = error.postalLoadFailure
                }
            }
            sentLoadTask = task
            await task.value
        }

        @MainActor
        func loadInboundLetters() async {
            inboundLoadTask?.cancel()
            let task = Task { @MainActor in
                isLoadingInbound = true
                defer { isLoadingInbound = false }

                do {
                    let items = try await api.listInboundLetterSummaries()
                    guard !Task.isCancelled else { return }
                    inboundLetters = items
                    inboundLoadFailure = nil
                    hasLoadedInbound = true
                    scheduleEndpointResolution()
                } catch {
                    guard !error.isPostalCancellation, !Task.isCancelled else { return }
                    inboundLoadFailure = error.postalLoadFailure
                }
            }
            inboundLoadTask = task
            await task.value
        }

        func resolved(_ endpoint: LetterEndpoint) -> ResolvedLetterEndpoint {
            let mailbox = endpoint.mailboxID.flatMap { mailboxesByID[$0] }
            let location = endpoint.mailboxID.flatMap { locationsByCode[$0.postOfficeID] }
            return ResolvedLetterEndpoint(endpoint: endpoint, mailbox: mailbox, location: location)
        }

        private func scheduleEndpointResolution() {
            resolutionTask?.cancel()
            let snapshot = letters + inboundLetters
            resolutionTask = Task {
                await resolveEndpoints(for: snapshot)
            }
        }

        private func resolveEndpoints(for letters: [LetterSummary]) async {
            let mailboxIDs = Set(
                letters.flatMap { letter in
                    [letter.origin.mailboxID, letter.destination.mailboxID].compactMap { $0 }
                }
            )
            let locationCodes = Set(mailboxIDs.map(\.postOfficeID))

            async let ownedMailboxesResult: [MailboxSummary] = {
                (try? await api.listOwnedMailboxes()) ?? []
            }()

            var fetchedLocations: [Int: Location] = [:]
            await withTaskGroup(of: (Int, Location?).self) { group in
                for code in locationCodes where locationsByCode[code] == nil {
                    group.addTask {
                        (code, try? await self.api.fetchLocation(code: code))
                    }
                }
                for await (code, location) in group {
                    if let location {
                        fetchedLocations[code] = location
                    }
                }
            }

            guard !Task.isCancelled else { return }

            let ownedMailboxes = await ownedMailboxesResult
            var mailboxMap = mailboxesByID
            for mailbox in ownedMailboxes {
                mailboxMap[mailbox.id] = mailbox
            }

            mailboxesByID = mailboxMap
            locationsByCode.merge(fetchedLocations) { _, new in new }
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        LettersListView(viewmodel: .preview(letters: []), loadsOnAppear: false)
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("Populated") {
    NavigationStack {
        LettersListView(viewmodel: .preview(), loadsOnAppear: false)
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("Single Letter") {
    NavigationStack {
        LettersListView(viewmodel: .preview(letters: [PreviewData.letterInTransit]), loadsOnAppear: false)
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("All Statuses") {
    NavigationStack {
        LettersListView(viewmodel: .preview(letters: PreviewData.letters), loadsOnAppear: false)
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("Inbound") {
    NavigationStack {
        LettersListView(viewmodel: .preview(inboundLetters: PreviewData.inboundLetters), loadsOnAppear: false)
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}
