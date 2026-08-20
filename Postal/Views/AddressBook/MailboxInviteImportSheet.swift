import SwiftUI

/// Confirms adding a shared mailbox invite to the address book.
struct MailboxInviteImportSheet: View {
    let mailboxID: MailboxID
    let api: APIClient
    var onSaved: ((AddressBookEntrySummary, MailboxSummary) -> Void)? = nil
    var onDismissed: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var invite: MailboxInvite?
    @State private var nickname = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var loadFailure: PostalLoadFailure?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && invite == nil {
                    ProgressView("Looking up mailbox…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadFailure, invite == nil {
                    ContentUnavailableView {
                        Label(loadFailure.title(resource: "Invite"), systemImage: loadFailure.systemImage)
                    } description: {
                        Text(loadFailure.message)
                    } actions: {
                        Button("Try Again") {
                            Task { await loadInvite() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let invite {
                    Form {
                        Section {
                            LabeledContent("Mailbox", value: invite.label)
                            LabeledContent("Post Office", value: invite.postOffice.name)
                            LabeledContent("Code", value: invite.mailboxID.code)
                        } header: {
                            Text("Shared Mailbox")
                        }

                        Section {
                            TextField("Nickname", text: $nickname)
                        } footer: {
                            Text("Saved to your address book so you can send letters here.")
                        }

                        if let saveError {
                            Section {
                                Text(saveError)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Address Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) {
                            close()
                        }
                        .disabled(isSaving)
                    } else {
                        Button("Not Now") {
                            close()
                        }
                        .disabled(isSaving)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) {
                            Task { await save() }
                        }
                        .disabled(!canSave)
                    } else {
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Add")
                            }
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .task {
                await loadInvite()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSave: Bool {
        invite != nil
            && !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
            && !isLoading
    }

    @MainActor
    private func loadInvite() async {
        isLoading = true
        loadFailure = nil
        defer { isLoading = false }

        do {
            let fetched = try await api.fetchMailboxInvite(mailboxID: mailboxID)
            invite = fetched
            if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nickname = fetched.label
            }
            loadFailure = nil
        } catch {
            guard !error.isPostalCancellation else { return }
            loadFailure = error.postalLoadFailure
        }
    }

    @MainActor
    private func save() async {
        guard let invite else { return }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            let saved = try await api.createAddressBookEntry(
                nickname: trimmed,
                mailboxID: invite.mailboxID
            )
            onSaved?(saved, invite.mailboxSummary)
            close()
        } catch {
            guard !error.isPostalCancellation else { return }
            saveError = error.postalLoadFailure.message
        }
    }

    private func close() {
        onDismissed?()
        dismiss()
    }
}

#Preview {
    MailboxInviteImportSheet(
        mailboxID: PreviewData.destinationMailboxes[0].id,
        api: APIClient()
    )
}
