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
    @State private var showQRSheet = false

    private var shareURL: URL {
        DeepLink.inviteURL(for: mailbox.id)
    }

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
            .sheet(isPresented: $showQRSheet) {
                MailboxInviteShareQRSheet(mailbox: mailbox)
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

struct MailboxInviteShareQRSheet: View {
    let mailbox: MailboxSummary

    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?
    @State private var didFailGeneration = false

    private var shareURL: URL {
        DeepLink.inviteURL(for: mailbox.id)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                qrContent
                    .padding()
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))

                Text(shareURL.absoluteString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                ShareLink(item: shareURL) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle(mailbox.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) { dismiss() }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .subtitle) {
                        Text(mailbox.locationLabel)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .task(id: shareURL.absoluteString) {
                await generateQR()
            }

        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var qrContent: some View {
        if let qrImage {
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else if didFailGeneration {
            ContentUnavailableView(
                "QR Unavailable",
                systemImage: "qrcode",
                description: Text("Couldn’t generate a QR code for this link.")
            )
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .overlay {
                    ProgressView()
                }
                .redacted(reason: .placeholder)
        }
    }

    @MainActor
    private func generateQR() async {
        didFailGeneration = false
        qrImage = nil
        let urlString = shareURL.absoluteString
        let image = await QRCodeImage.make(from: urlString)
        qrImage = image
        didFailGeneration = image == nil
    }
}

#Preview("Settings") {
    MailboxSettingsSheet(
        mailbox: PreviewData.ownedMailboxes[0],
        api: APIClient(),
        onRelinquished: {}
    )
}

#Preview("QR"){
    MailboxInviteShareQRSheet(mailbox: PreviewData.ownedMailboxes[0])
}
