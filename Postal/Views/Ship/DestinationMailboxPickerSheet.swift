import SwiftUI

struct DestinationMailboxPickerSheet: View {
    let api: APIClient
    let onSelect: (MailboxSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var mailboxCode = ""
    @State private var postOffices: [PostOffice] = []
    @State private var selectedPostOffice: PostOffice?
    @State private var isLoadingPostOffices = false
    @State private var isValidatingMailbox = false
    @State private var hasLoadedPostOffices = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let selectedPostOffice {
                    mailboxCodeEntry(for: selectedPostOffice)
                } else {
                    postOfficeList
                }
            }
            .navigationTitle(selectedPostOffice?.name ?? "Choose Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) { dismiss() }
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
                if selectedPostOffice != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedPostOffice = nil
                            mailboxCode = ""
                            searchText = ""
                            errorMessage = nil
                        } label: {
                            Label("Post Offices", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Select") {
                            if let selectedPostOffice {
                                Task { await confirmMailbox(for: selectedPostOffice) }
                            }
                        }
                        .disabled(!canConfirmMailbox || isValidatingMailbox)
                    }
                }
            }
            .overlay {
                if showsLoadingOverlay {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
        .task(id: searchText) {
            guard selectedPostOffice == nil else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await searchPostOffices()
        }
    }

    private var canConfirmMailbox: Bool {
        !mailboxCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsLoadingOverlay: Bool {
        isLoadingPostOffices && !hasLoadedPostOffices
    }

    @ViewBuilder
    private var postOfficeList: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if postOffices.isEmpty, !isLoadingPostOffices {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(postOffices) { office in
                    Button {
                        selectedPostOffice = office
                        mailboxCode = ""
                        searchText = ""
                        errorMessage = nil
                    } label: {
                        Text(office.name)
                            .foregroundStyle(.primary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search post offices"
        )
    }

    @ViewBuilder
    private func mailboxCodeEntry(for postOffice: PostOffice) -> some View {
        Form {
            Section {
                Text(postOffice.name)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Post Office")
            }

            Section {
                TextField("Mailbox code", text: $mailboxCode, prompt: Text("7XK9M"))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())

                if isValidatingMailbox {
                    HStack {
                        ProgressView()
                        Text("Looking up mailbox…")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Mailbox Code")
            } footer: {
                Text("Enter the destination mailbox code at this post office.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func searchPostOffices() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isInitialLoad = !hasLoadedPostOffices
        if isInitialLoad {
            isLoadingPostOffices = true
        }
        errorMessage = nil
        defer {
            if isInitialLoad {
                isLoadingPostOffices = false
            }
        }

        do {
            postOffices = try await api.listPostOffices(
                search: query.isEmpty ? nil : query,
                limit: 100
            )
            hasLoadedPostOffices = true
        } catch {
            postOffices = []
            errorMessage = error.localizedDescription
            hasLoadedPostOffices = true
        }
    }

    private func confirmMailbox(for postOffice: PostOffice) async {
        let code = mailboxCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }

        isValidatingMailbox = true
        errorMessage = nil
        defer { isValidatingMailbox = false }

        do {
            let mailbox = try await api.lookupMailbox(postOfficeID: postOffice.id, code: code)
            onSelect(mailbox)
            dismiss()
        } catch let error as MailboxLookupError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum MailboxLookupError: LocalizedError {
    case notFound(code: String)

    var errorDescription: String? {
        switch self {
        case let .notFound(code):
            return "No mailbox found with code \(code) at this post office."
        }
    }
}

#Preview("Post Offices") {
    DestinationMailboxPickerSheet(api: APIClient()) { _ in }
}

#Preview("Mailbox Code") {
    struct PreviewHost: View {
        var body: some View {
            DestinationMailboxPickerSheet(api: APIClient()) { _ in }
        }
    }
    return PreviewHost()
}
