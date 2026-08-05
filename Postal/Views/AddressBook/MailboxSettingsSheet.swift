import SwiftUI

struct MailboxSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mailbox: MailboxSummary
    let api: APIClient
    var onRelinquished: () -> Void

    @State private var preview: RelinquishMailboxPreview?
    @State private var isLoadingPreview = false
    @State private var isRelinquishing = false
    @State private var isConfirmingRelinquish = false
    @State private var previewFailure: PostalLoadFailure?
    @State private var errorMessage: String?
    @State private var sharePlaceholderMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Location", value: mailbox.locationLabel)
                    LabeledContent("Code", value: mailbox.id.code)
                } header: {
                    Text("Mailbox")
                }

                Section {
                    Button {
                        sharePlaceholderMessage = "Sharing a mailbox link isn’t available yet."
                    } label: {
                        Label("Share Mailbox URL", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    if isLoadingPreview, preview == nil {
                        HStack {
                            ProgressView()
                            Text("Checking inbound letters…")
                                .foregroundStyle(.secondary)
                        }
                    } else if let preview {
                        if preview.willFailCount > 0 {
                            Text(
                                preview.willFailCount == 1
                                    ? "1 inbound letter is still in progress and will be failed."
                                    : "\(preview.willFailCount) inbound letters are still in progress and will be failed."
                            )
                            .foregroundStyle(.secondary)

                            ForEach(preview.inboundLetters.filter(\.willFail)) { letter in
                                HStack {
                                    Image(systemName: letter.status.iconName)
                                        .foregroundStyle(letter.status.tintColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(letter.status.displayTitle)
                                            .font(.body)
                                        Text(letter.id)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        } else if preview.inboundLetters.isEmpty {
                            Text("No inbound letters. You can safely relinquish this mailbox.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("All inbound letters are already complete. You can relinquish this mailbox.")
                                .foregroundStyle(.secondary)
                        }
                    } else if let previewFailure {
                        Label(previewFailure.title(resource: "Inbound"), systemImage: previewFailure.systemImage)
                        Text(previewFailure.message)
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            Task { await loadPreview() }
                        }
                    }

                    Button(role: .destructive) {
                        isConfirmingRelinquish = true
                    } label: {
                        if isRelinquishing {
                            HStack {
                                ProgressView()
                                Text("Relinquishing…")
                            }
                        } else {
                            Label("Relinquish Mailbox", systemImage: "trash")
                        }
                    }
                    .disabled(isRelinquishing || isLoadingPreview)
                } header: {
                    Text("Relinquish")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Mailbox Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                        .disabled(isRelinquishing)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Label("Done", systemImage: "xmark")
                        }
                        .disabled(isRelinquishing)
                    }
                }
            }
            .interactiveDismissDisabled(isRelinquishing)
            .task {
                await loadPreview()
            }
            .alert(
                "Relinquish Mailbox?",
                isPresented: $isConfirmingRelinquish
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Relinquish", role: .destructive) {
                    Task { await relinquish() }
                }
            } message: {
                Text(relinquishConfirmationMessage)
            }
            .alert(
                "Share",
                isPresented: Binding(
                    get: { sharePlaceholderMessage != nil },
                    set: { if !$0 { sharePlaceholderMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    sharePlaceholderMessage = nil
                }
            } message: {
                Text(sharePlaceholderMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var relinquishConfirmationMessage: String {
        if preview == nil {
            return "Couldn't verify inbound letters for \(mailbox.label). Relinquishing anyway may fail active deliveries. This cannot be undone."
        }
        let failCount = preview?.willFailCount ?? 0
        if failCount > 0 {
            let letterWord = failCount == 1 ? "letter" : "letters"
            return "This will fail \(failCount) active inbound \(letterWord) and release \(mailbox.label). This cannot be undone."
        }
        return "This releases \(mailbox.label) so its code can be claimed by someone else. This cannot be undone."
    }

    private func loadPreview() async {
        isLoadingPreview = true
        previewFailure = nil
        errorMessage = nil
        defer { isLoadingPreview = false }

        do {
            preview = try await api.relinquishMailboxPreview(mailboxID: mailbox.id)
            previewFailure = nil
        } catch {
            guard !error.isPostalCancellation else { return }
            previewFailure = error.postalLoadFailure
        }
    }

    private func relinquish() async {
        isRelinquishing = true
        errorMessage = nil
        defer { isRelinquishing = false }

        do {
            try await api.relinquishMailbox(mailboxID: mailbox.id)
            onRelinquished()
            dismiss()
        } catch {
            guard !error.isPostalCancellation else { return }
            errorMessage = error.postalLoadFailure.message
        }
    }
}

#Preview {
    MailboxSettingsSheet(
        mailbox: PreviewData.ownedMailboxes[0],
        api: APIClient(),
        onRelinquished: {}
    )
}
