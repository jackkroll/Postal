import SwiftUI

struct DestinationMailboxPickerSheet: View {
    let api: APIClient
    var title: String = "Choose Destination"
    /// Address Book shortcut for destination picking. Hidden when already selecting from the book
    /// (e.g. nested mailbox lookup while editing an address-book entry).
    var showsAddressBookShortcut: Bool = true
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
                    MailboxCodeEntryView(
                        postOffice: selectedPostOffice,
                        mailboxCode: $mailboxCode,
                        isValidating: isValidatingMailbox,
                        errorMessage: errorMessage
                    )
                } else {
                    PostOfficeListView(
                        postOffices: postOffices,
                        searchText: $searchText,
                        isLoading: isLoadingPostOffices,
                        errorMessage: errorMessage,
                        onRetry: { Task { await searchPostOffices() } },
                        onSelect: selectPostOffice(_:)
                    )
                }
            }
            .navigationTitle(selectedPostOffice?.name ?? title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) { dismiss() }
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }

                if showsAddressBookShortcut, selectedPostOffice == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            AddressBook(viewmodel: .init(api: api)) { entry in
                                onSelect(entry.mailboxSummary)
                                dismiss()
                            }
                        } label: {
                            Label("Address Book", systemImage: "book")
                        }
                    }
                }

                if selectedPostOffice != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            clearSelection()
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
                if isLoadingPostOffices && !hasLoadedPostOffices {
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
        MailboxCodeValidation.isValid(mailboxCode)
    }

    private func selectPostOffice(_ office: PostOffice) {
        selectedPostOffice = office
        mailboxCode = ""
        searchText = ""
        errorMessage = nil
    }

    private func clearSelection() {
        selectedPostOffice = nil
        mailboxCode = ""
        searchText = ""
        errorMessage = nil
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
            let offices = try await api.listPostOffices(
                search: query.isEmpty ? nil : query,
                limit: 100
            )
            try Task.checkCancellation()
            postOffices = offices
            hasLoadedPostOffices = true
        } catch is CancellationError {
            // Debounced `.task(id:)` cancels in-flight work when the query changes.
        } catch let error as URLError where error.code == .cancelled {
            // URLSession surfaces cancellation this way.
        } catch {
            guard !Task.isCancelled else { return }
            postOffices = []
            errorMessage = error.localizedDescription
            hasLoadedPostOffices = true
        }
    }

    private func confirmMailbox(for postOffice: PostOffice) async {
        guard PostOfficeValidation.isValidID(postOffice.id) else {
            errorMessage = MailboxLookupError.invalidPostOfficeID(postOffice.id).localizedDescription
            return
        }

        let code = MailboxCodeValidation.normalized(mailboxCode)
        guard MailboxCodeValidation.isValid(code) else {
            errorMessage = MailboxLookupError.invalidMailboxCode(code).localizedDescription
            return
        }

        isValidatingMailbox = true
        errorMessage = nil
        defer { isValidatingMailbox = false }

        do {
            let mailbox = try await api.lookupMailbox(postOffice: postOffice, code: code)
            onSelect(mailbox)
            dismiss()
        } catch let error as MailboxLookupError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Post Office List

private struct PostOfficeListView: View {
    let postOffices: [PostOffice]
    @Binding var searchText: String
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onSelect: (PostOffice) -> Void

    var body: some View {
        Group {
            if let errorMessage, postOffices.isEmpty, !isLoading {
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again", action: onRetry)
                }
            } else if postOffices.isEmpty, !isLoading {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(postOffices) { office in
                    Button {
                        onSelect(office)
                    } label: {
                        PostOfficeLocationRow(postOffice: office)
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
}

/// One row per post office so location-specific state can live next to the office it describes.
private struct PostOfficeLocationRow: View {
    let postOffice: PostOffice

    @State private var locationLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(postOffice.name)
                .foregroundStyle(.primary)

            if let locationLabel {
                Text(locationLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: postOffice.id) {
            guard let details = try? await postOffice.getLocationDetails() else { return }
            locationLabel = details
        }
    }
}

// MARK: - Mailbox Code Entry

private struct MailboxCodeEntryView: View {
    let postOffice: PostOffice
    @Binding var mailboxCode: String
    let isValidating: Bool
    let errorMessage: String?

    var body: some View {
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
                    .onChange(of: mailboxCode) { _, newValue in
                        let sanitized = Self.sanitizedMailboxCode(newValue)
                        if sanitized != newValue {
                            mailboxCode = sanitized
                        }
                    }

                if isValidating {
                    HStack {
                        ProgressView()
                        Text("Looking up mailbox…")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Mailbox Code")
            } footer: {
                Text("Enter the destination mailbox code at this post office (letters and numbers only).")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    /// Forces uppercase alphanumeric codes so paste / hardware keyboards stay consistent
    /// with soft-keyboard autocapitalization.
    private static func sanitizedMailboxCode(_ raw: String) -> String {
        let uppercased = raw.uppercased()
        let filtered = uppercased.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filtered).prefix(MailboxCodeValidation.maximumLength))
    }
}

#Preview("Post Offices") {
    DestinationMailboxPickerSheet(api: APIClient()) { _ in }
}

#Preview("Mailbox Code") {
    DestinationMailboxPickerSheet(api: APIClient()) { _ in }
}

#Preview("Post Office Row") {
    List {
        PostOfficeLocationRow(postOffice: PreviewData.mainStreetPostOffice)
        PostOfficeLocationRow(postOffice: PreviewData.riversideStation)
        PostOfficeLocationRow(postOffice: PreviewData.westsideDeliveryOffice)
    }
}
