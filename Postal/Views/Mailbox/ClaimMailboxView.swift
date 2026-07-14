import SwiftUI

struct ClaimMailboxView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewmodel: ViewModel

    init(viewmodel: ViewModel = ViewModel(api: AppServices.api)) {
        _viewmodel = State(initialValue: viewmodel)
    }

    var body: some View {
        Group {
            if let selectedPostOffice = viewmodel.selectedPostOffice {
                claimConfirmation(for: selectedPostOffice)
            } else {
                postOfficeList
            }
        }
        .navigationTitle(viewmodel.selectedPostOffice?.name ?? "Claim Mailbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewmodel.selectedPostOffice != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewmodel.isClaiming ? "Claiming…" : "Claim") {
                        Task { await viewmodel.claim() }
                    }
                    .disabled(!viewmodel.canClaim)
                }
            }
        }
        .overlay {
            if viewmodel.showsLoadingOverlay {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .alert("Mailbox Claimed", isPresented: $viewmodel.showSuccess) {
            Button("Done") {
                dismiss()
            }
        } message: {
            if let mailbox = viewmodel.claimedMailbox {
                Text("\(mailbox.label)\n\(mailbox.locationLabel)")
            }
        }
        .task(id: viewmodel.searchText) {
            guard viewmodel.selectedPostOffice == nil else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await viewmodel.searchPostOffices()
        }
    }

    @ViewBuilder
    private var postOfficeList: some View {
        Group {
            if let errorMessage = viewmodel.errorMessage, viewmodel.postOffices.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if viewmodel.postOffices.isEmpty, !viewmodel.isLoadingPostOffices {
                ContentUnavailableView.search(text: viewmodel.searchText)
            } else {
                List(viewmodel.postOffices) { office in
                    Button {
                        viewmodel.selectPostOffice(office)
                    } label: {
                        Text(office.name)
                            .foregroundStyle(.primary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(
            text: $viewmodel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search post offices"
        )
    }

    @ViewBuilder
    private func claimConfirmation(for postOffice: PostOffice) -> some View {
        Form {
            Section {
                Text(postOffice.name)
                    .foregroundStyle(.secondary)

                Button("Choose a different post office") {
                    viewmodel.clearSelection()
                }
                .disabled(viewmodel.isClaiming)
            } header: {
                Text("Post Office")
            } footer: {
                Text("A free mailbox at this post office will be assigned to you.")
            }

            if viewmodel.isClaiming {
                Section {
                    HStack {
                        ProgressView()
                        Text("Claiming mailbox…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage = viewmodel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

extension ClaimMailboxView {
    @Observable
    class ViewModel {
        let api: APIClient

        var searchText = ""
        var postOffices: [PostOffice] = []
        var selectedPostOffice: PostOffice?
        var claimedMailbox: MailboxSummary?

        var isLoadingPostOffices = false
        var hasLoadedPostOffices = false
        var isClaiming = false
        var errorMessage: String?
        var showSuccess = false

        var canClaim: Bool {
            selectedPostOffice != nil && !isClaiming
        }

        var showsLoadingOverlay: Bool {
            isLoadingPostOffices && !hasLoadedPostOffices
        }

        init(api: APIClient) {
            self.api = api
        }

        func selectPostOffice(_ office: PostOffice) {
            selectedPostOffice = office
            errorMessage = nil
        }

        func clearSelection() {
            selectedPostOffice = nil
            errorMessage = nil
        }

        func searchPostOffices() async {
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

        func claim() async {
            guard let postOffice = selectedPostOffice else { return }

            isClaiming = true
            errorMessage = nil
            defer { isClaiming = false }

            do {
                let mailbox = try await api.claimMailbox(postOfficeID: postOffice.id)
                claimedMailbox = mailbox
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview("Post Offices") {
    NavigationStack {
        ClaimMailboxView(viewmodel: .preview())
    }
}

#Preview("Confirm") {
    NavigationStack {
        ClaimMailboxView(viewmodel: .preview(
            postOffices: PreviewData.postOffices,
            selectedPostOffice: PreviewData.mainStreetPostOffice,
            hasLoadedPostOffices: true
        ))
    }
}
