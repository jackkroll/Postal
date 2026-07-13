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
                    }
                } else {
                    Picker("Send from", selection: $viewmodel.selectedOriginMailboxID) {
                        Text("Select a mailbox").tag(Optional<String>.none)
                        ForEach(viewmodel.ownedMailboxes) { mailbox in
                            Text(mailbox.pickerLabel).tag(Optional(mailbox.id))
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
        .task {
            await viewmodel.loadMailboxes()
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
        var selectedOriginMailboxID: String?
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
                && selectedOriginMailboxID != nil
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
                if selectedOriginMailboxID == nil, ownedMailboxes.count == 1 {
                    selectedOriginMailboxID = ownedMailboxes[0].id
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func send() async {
            guard canSend,
                  let originBoxID = selectedOriginMailboxID,
                  let destinationBoxID = selectedDestinationMailbox?.id
            else { return }

            isSending = true
            errorMessage = nil
            defer { isSending = false }

            let request = CreateShipmentRequest(
                originBoxID: originBoxID,
                destinationBoxID: destinationBoxID,
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
            selectedOriginMailboxID: PreviewData.ownedMailboxes[0].id,
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
