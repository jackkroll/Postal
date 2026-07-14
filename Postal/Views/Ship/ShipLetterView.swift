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
                    Picker("Send from", selection: $viewmodel.selectedOriginMailbox) {
                        Text("Select a mailbox").tag(Optional<MailboxSummary>.none)
                        ForEach(viewmodel.ownedMailboxes) { mailbox in
                            Text(mailbox.pickerLabel).tag(Optional(mailbox))
                        }
                    }
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

            Section {
                TextEditor(text: $viewmodel.letterText)
                    .frame(minHeight: 180)

                HStack {
                    Text(byteCountLabel)
                        .font(.caption)
                        .foregroundStyle(viewmodel.isOverByteLimit ? .red : .secondary)
                    Spacer()
                    if viewmodel.letterText.isEmpty {
                        Text("Required")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Message")
            } footer: {
                Text("Text letters only for now. Image and drawing support coming later.")
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(viewmodel.isSending ? "Sending…" : "Send") {
                    Task { await viewmodel.send() }
                }
                .disabled(!viewmodel.canSend)
            }
        }
        .onAppear {
            Task { await viewmodel.loadMailboxes() }
        }
        .sheet(isPresented: $viewmodel.isDestinationPickerPresented) {
            DestinationMailboxPickerSheet(api: viewmodel.api) { mailbox in
                viewmodel.selectDestination(mailbox)
            }
        }
        .alert("Letter Sent", isPresented: $viewmodel.showSuccess) {
            Button("Done") {
                dismiss()
            }
        } message: {
            if let trackingNumber = viewmodel.createdTrackingNumber {
                Text("Tracking number:\n\(trackingNumber)")
            }
        }
    }

    private var byteCountLabel: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let current = formatter.string(fromByteCount: Int64(viewmodel.letterByteCount))
        let max = formatter.string(fromByteCount: Int64(ViewModel.maxLetterBytes))
        return "\(current) / \(max)"
    }
}

extension ShipLetterView {
    @Observable
    class ViewModel {
        static let maxLetterBytes = 65_536

        let api: APIClient
        var ownedMailboxes: [MailboxSummary] = []
        var selectedOriginMailbox: MailboxSummary?
        var selectedDestinationMailbox: MailboxSummary?
        var isDestinationPickerPresented = false

        var letterText = ""
        var isLoadingMailboxes = false
        var isSending = false
        var errorMessage: String?
        var showSuccess = false
        var createdTrackingNumber: String?

        var letterByteCount: Int {
            letterText.utf8.count
        }

        var isOverByteLimit: Bool {
            letterByteCount > Self.maxLetterBytes
        }

        var canSend: Bool {
            !isSending
                && selectedOriginMailbox != nil
                && selectedDestinationMailbox != nil
                && !trimmed(letterText).isEmpty
                && !isOverByteLimit
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
                let mailboxes = try await api.listOwnedMailboxes()
                ownedMailboxes = mailboxes.filter(\.owned)
                if selectedOriginMailbox == nil, ownedMailboxes.count == 1 {
                    selectedOriginMailbox = ownedMailboxes[0]
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func send() async {
            guard canSend,
                  let origin = selectedOriginMailbox,
                  let destination = selectedDestinationMailbox
            else { return }

            isSending = true
            errorMessage = nil
            defer { isSending = false }

            let request = CreateShipmentRequest(
                origin: origin,
                destination: destination,
                letter: .plain(trimmed(letterText))
            )

            do {
                let response = try await api.createShipment(request)
                createdTrackingNumber = response.trackingNumber
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        private func trimmed(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
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
