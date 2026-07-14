import SwiftUI

struct LettersListView: View {
    @State private var viewmodel: ViewModel

    init(
        viewmodel: ViewModel = ViewModel(
            auth: AppServices.auth,
            lettersService: AppServices.letters,
            api: AppServices.api
        )
    ) {
        _viewmodel = State(initialValue: viewmodel)
    }

    var body: some View {
        Group {
            if viewmodel.letters.isEmpty {
                ContentUnavailableView {
                    Label("No Letters Yet", systemImage: "envelope.open")
                } description: {
                    Text("Shipments you create will appear here.")
                } actions: {
                    NavigationLink("Ship a Letter", value: ViewRoute.ship)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(viewmodel.letters) { letter in
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
        .navigationTitle("My Letters")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(value: ViewRoute.ship) {
                    Label("Ship", systemImage: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: ViewRoute.claimBox) {
                    Label("Claim Mailbox", systemImage: "tray.and.arrow.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") {
                    try? viewmodel.auth.signOut()
                }
            }
        }
        .onAppear(perform: viewmodel.startListening)
        .onDisappear(perform: viewmodel.stopListening)
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
        var auth: AuthProviding
        var lettersService: LettersProviding
        var api: APIClient
        var letters: [LetterSummary] = []
        var mailboxesByID: [MailboxID: MailboxSummary] = [:]
        var locationsByCode: [Int: Location] = [:]
        var listenerToken: AnyObject?

        private var resolutionTask: Task<Void, Never>?

        init(auth: AuthProviding, lettersService: LettersProviding, api: APIClient) {
            self.auth = auth
            self.lettersService = lettersService
            self.api = api
        }

        func startListening() {
            guard let userID = auth.currentUserID else { return }
            stopListening()
            listenerToken = lettersService.startListening(userID: userID) { updatedLetters in
                self.letters = updatedLetters.sorted { $0.sortDate > $1.sortDate }
                self.scheduleEndpointResolution()
            }
        }

        func stopListening() {
            lettersService.stopListening(listenerToken)
            listenerToken = nil
            resolutionTask?.cancel()
            resolutionTask = nil
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

            // Resolve remaining mailbox labels via post-office mailbox lists.
            let missingMailboxIDs = mailboxIDs.filter { mailboxMap[$0] == nil }
            let missingByPostOffice = Dictionary(grouping: missingMailboxIDs, by: \.postOfficeID)

            await withTaskGroup(of: [MailboxSummary].self) { group in
                for (postOfficeID, ids) in missingByPostOffice {
                    group.addTask {
                        guard let listed = try? await self.api.listMailboxes(postOfficeID: postOfficeID) else {
                            return []
                        }
                        let wanted = Set(ids)
                        return listed.filter { wanted.contains($0.id) }
                    }
                }
                for await matches in group {
                    for mailbox in matches {
                        mailboxMap[mailbox.id] = mailbox
                    }
                }
            }

            guard !Task.isCancelled else { return }

            mailboxesByID = mailboxMap
            locationsByCode.merge(fetchedLocations) { _, new in new }
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        LettersListView(viewmodel: .preview(letters: []))
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("Populated") {
    NavigationStack {
        LettersListView(viewmodel: .preview())
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("Single Letter") {
    NavigationStack {
        LettersListView(viewmodel: .preview(letters: [PreviewData.letterInTransit]))
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("All Statuses") {
    NavigationStack {
        LettersListView(viewmodel: .preview(letters: PreviewData.letters))
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}
