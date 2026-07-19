import SwiftUI

struct ShipLetterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewmodel: ViewModel

    init(viewmodel: ViewModel = ViewModel(api: AppServices.api)) {
        _viewmodel = State(initialValue: viewmodel)
    }

    var body: some View {
        Form {
            Section {
                if viewmodel.isLoadingMailboxes {
                    HStack {
                        ProgressView()
                        Text("Loading your mailboxes…")
                            .foregroundStyle(.secondary)
                    }
                } else if viewmodel.ownedMailboxes.isEmpty {
                    ContentUnavailableView {
                        Label("No Mailboxes", systemImage: "tray")
                    } description: {
                        Text("Claim a mailbox before sending letters.")
                    } actions: {
                        NavigationLink("Claim a Mailbox", value: ViewRoute.claimBox)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Menu + ID-based selection avoids Picker hashing large MailboxSummary
                    // values on every open/selection, which was causing menu lag.
                    Picker("Send from", selection: $viewmodel.selectedOriginMailboxID) {
                        Text("Select a mailbox").tag(Optional<MailboxID>.none)
                        ForEach(viewmodel.ownedMailboxes) { mailbox in
                            Text(mailbox.pickerLabel).tag(Optional(mailbox.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("From")
            } footer: {
                Text("Choose one of your claimed mailboxes.")
            }

            Section {
                Button {
                    viewmodel.isDestinationPickerPresented = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let mailbox = viewmodel.selectedDestinationMailbox {
                                Text(mailbox.label)
                                    .foregroundStyle(.primary)
                                Text(mailbox.locationLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Select destination")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("To")
            } footer: {
                Text("Search for a post office, then enter the destination mailbox code.")
            }
            if let source = viewmodel.selectedOriginMailbox, let destination = viewmodel.selectedDestinationMailbox {
                NavigationLink(value: ViewRoute.compose(source: source, destination: destination)) {
                    Text("Compose Letter")
                }
            }
            if let errorMessage = viewmodel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Ship Letter")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewmodel.loadMailboxes()
        }
        .sheet(isPresented: $viewmodel.isDestinationPickerPresented) {
            DestinationMailboxPickerSheet(api: viewmodel.api) { mailbox in
                viewmodel.selectDestination(mailbox)
            }
        }
    }
}

extension ShipLetterView {
    @Observable
    class ViewModel {
        static let maxLetterBytes = 65_536

        let api: APIClient
        var ownedMailboxes: [MailboxSummary] = []
        /// Selection stored by ID so Picker tags stay cheap to hash/diff.
        var selectedOriginMailboxID: MailboxID?
        var selectedDestinationMailbox: MailboxSummary?
        var isDestinationPickerPresented = false
        var isLoadingMailboxes = false
        var errorMessage: String?

        var selectedOriginMailbox: MailboxSummary? {
            guard let selectedOriginMailboxID else { return nil }
            return ownedMailboxes.first { $0.id == selectedOriginMailboxID }
        }

        var canCompose: Bool {
            selectedOriginMailbox != nil && selectedDestinationMailbox != nil
        }

        init(api: APIClient) {
            self.api = api
        }

        func selectDestination(_ mailbox: MailboxSummary) {
            selectedDestinationMailbox = mailbox
        }

        func loadMailboxes() async {
            isLoadingMailboxes = true
            errorMessage = nil
            defer { isLoadingMailboxes = false }

            do {
                ownedMailboxes = try await api.listOwnedMailboxes()
                if selectedOriginMailboxID == nil, ownedMailboxes.count == 1 {
                    selectedOriginMailboxID = ownedMailboxes[0].id
                } else if let selectedOriginMailboxID,
                          !ownedMailboxes.contains(where: { $0.id == selectedOriginMailboxID }) {
                    self.selectedOriginMailboxID = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        ShipLetterView(viewmodel: .preview())
    }
}

#Preview("Ready To Send") {
    NavigationStack {
        ShipLetterView(viewmodel: .preview(
            ownedMailboxes: PreviewData.ownedMailboxes,
            selectedOriginMailbox: PreviewData.ownedMailboxes[0],
            selectedDestinationMailbox: PreviewData.destinationMailboxes[1],
            letterText: PreviewData.sampleLetterText
        ))
    }
}

#Preview("No Mailboxes") {
    NavigationStack {
        ShipLetterView(viewmodel: .preview(ownedMailboxes: []))
    }
}
