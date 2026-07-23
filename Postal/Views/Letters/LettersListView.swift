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
        if viewmodel.isLoadingSent, viewmodel.letters.isEmpty, viewmodel.drafts.isEmpty {
            ProgressView("Loading letters…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewmodel.sentErrorMessage, viewmodel.letters.isEmpty, viewmodel.drafts.isEmpty {
            ContentUnavailableView {
                Label("Couldn't Load Letters", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await viewmodel.loadSentLetters() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if viewmodel.letters.isEmpty, viewmodel.drafts.isEmpty {
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
                        if viewmodel.letters.isEmpty {
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
        if viewmodel.isLoadingInbound, viewmodel.inboundLetters.isEmpty {
            ProgressView("Loading inbound letters…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewmodel.inboundErrorMessage, viewmodel.inboundLetters.isEmpty {
            ContentUnavailableView {
                Label("Couldn't Load Inbound", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await viewmodel.loadInboundLetters() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if viewmodel.inboundLetters.isEmpty {
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
                        letter: letter.letterSummary,
                        isRecipient: true
                    )) {
                        InboundLetterRowView(letter: letter)
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
                    if let updated = letter.updatedAt ?? letter.createdAt {
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
                UIPasteboard.general.string = letter.trackingNumber
            } label: {
                Image(systemName: "document.on.document.fill")
                Text("Copy Tracking Number")
            }
        }
        .padding(.vertical, 2)
    }
}

private struct InboundLetterRowView: View {
    let letter: InboundLetterItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: letter.status.iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(letter.status.tintColor)
                .frame(maxWidth: 40, maxHeight: 40)
                .background(letter.status.tintColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(letter.destinationName)
                    .font(.headline)
                    .lineLimit(1)

                Text("From \(letter.originName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(letter.status.displayTitle)
                        .foregroundStyle(letter.status.tintColor)

                    if let updated = letter.updatedAt ?? letter.createdAt {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(updated, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                            .foregroundStyle(.secondary)
                    }

                    if letter.hasLetter, let format = letter.letterFormat {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(format.displayTitle)
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)

                Text(letter.trackingNumber)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = letter.trackingNumber
            } label: {
                Image(systemName: "document.on.document.fill")
                Text("Copy Tracking Number")
            }
        }
        .padding(.vertical, 2)
    }
}

extension LettersListView {
    @Observable
    class ViewModel {
        var api: APIClient
        var draftsStore: DraftLetterStoring
        var letters: [LetterSummary] = []
        var drafts: [LetterDraft] = []
        var inboundLetters: [InboundLetterItem] = []
        var isLoadingSent = false
        var isLoadingInbound = false
        var sentErrorMessage: String?
        var inboundErrorMessage: String?
        var mailboxesByID: [MailboxID: MailboxSummary] = [:]
        var locationsByCode: [Int: Location] = [:]

        private var resolutionTask: Task<Void, Never>?
        private var sentLoadTask: Task<Void, Never>?
        private var inboundLoadTask: Task<Void, Never>?

        init(api: APIClient, draftsStore: DraftLetterStoring = AppServices.letterDrafts) {
            self.api = api
            self.draftsStore = draftsStore
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
                sentErrorMessage = nil
                defer { isLoadingSent = false }

                do {
                    let items = try await api.listSentLetterSummaries()
                    guard !Task.isCancelled else { return }
                    letters = items
                    scheduleEndpointResolution()
                } catch {
                    guard !Task.isCancelled else { return }
                    sentErrorMessage = error.localizedDescription
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
                inboundErrorMessage = nil
                defer { isLoadingInbound = false }

                do {
                    let items = try await api.listInboundLetterItems()
                    guard !Task.isCancelled else { return }
                    inboundLetters = items
                } catch {
                    guard !Task.isCancelled else { return }
                    inboundErrorMessage = error.localizedDescription
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
            let snapshot = letters
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
