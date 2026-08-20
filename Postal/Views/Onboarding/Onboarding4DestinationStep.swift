import SwiftUI

struct OnboardingDestinationStep: View {
    @Bindable var store: OnboardingStore
    let api: APIClient
    @Bindable private var pendingInvites: PendingMailboxInviteStore

    @Namespace private var scannerTransition
    @State private var showPicker = false
    @State private var showScanner = false
    @State private var pendingMailbox: MailboxSummary?
    @State private var nickname = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var scanError: String?

    init(
        store: OnboardingStore,
        api: APIClient = AppServices.api,
        pendingInvites: PendingMailboxInviteStore = AppServices.pendingMailboxInvites,
        pendingMailbox: MailboxSummary? = nil,
        nickname: String = ""
    ) {
        self.store = store
        self.api = api
        self.pendingInvites = pendingInvites
        _pendingMailbox = State(initialValue: pendingMailbox)
        _nickname = State(initialValue: nickname)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OnboardingStepHeader(
                    title: PromoText.onboardingDestinationTitle,
                    bodyText: PromoText.onboardingDestinationBody
                )

                if let pendingMailbox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Save “\(pendingMailbox.pickerLabel)” to your address book?")
                            .font(.subheadline.weight(.semibold))
                        TextField("Nickname (optional)", text: $nickname)
                            .textFieldStyle(.roundedBorder)
                        if let saveError {
                            Text(saveError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingBottomActions {
                if let pendingMailbox {
                    Button {
                        Task { await saveDestination(pendingMailbox) }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save & Continue")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSaving)

                    Button("Continue without saving") {
                        store.recordSavedDestination(pendingMailbox, nickname: nil)
                    }
                    .font(.body.weight(.medium))
                } else {
                    Button {
                        showPicker = true
                    } label: {
                        Text(PromoText.onboardingDestinationYes)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        showScanner = true
                    } label: {
                        Text(PromoText.onboardingDestinationScan)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .inviteScannerTransitionSource(id: "inviteScanner", in: scannerTransition)

                    Button {
                        store.recordDestinationSkipped()
                    } label: {
                        Text(PromoText.onboardingDestinationNo)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .navigationTitle("Destination")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            DestinationMailboxPickerSheet(api: api) { mailbox in
                pendingMailbox = mailbox
                nickname = mailbox.label
            }
        }
        .sheet(isPresented: $showScanner) {
            MailboxInviteQRScannerSheet(
                onCode: handleScannedPayload,
                onFailure: { scanError = $0 }
            )
            .inviteScannerZoomTransition(id: "inviteScanner", in: scannerTransition)
        }
        .sheet(item: inviteImportBinding) { mailboxID in
            MailboxInviteImportSheet(
                mailboxID: mailboxID,
                api: api,
                onSaved: { entry, mailbox in
                    store.recordSavedDestination(mailbox, nickname: entry.nickname)
                    pendingInvites.clear()
                },
                onDismissed: { pendingInvites.clear() }
            )
        }
        .alert(
            "Couldn’t Read Invite",
            isPresented: Binding(
                get: { scanError != nil },
                set: { if !$0 { scanError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { scanError = nil }
        } message: {
            Text(scanError ?? "")
        }
    }

    private var inviteImportBinding: Binding<MailboxID?> {
        Binding(
            get: { pendingInvites.offeredMailboxID },
            set: { newValue in
                if newValue == nil {
                    pendingInvites.clear()
                }
            }
        )
    }

    private func handleScannedPayload(_ payload: String) {
        if let mailboxID = DeepLink.mailboxID(fromInvitePayload: payload) {
            pendingInvites.offer(mailboxID)
        } else {
            scanError = "That QR code isn’t a Postal mailbox invite."
        }
    }

    @MainActor
    private func saveDestination(_ mailbox: MailboxSummary) async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? mailbox.label : trimmed

        do {
            _ = try await api.createAddressBookEntry(
                nickname: name,
                mailboxID: mailbox.id
            )
            store.recordSavedDestination(mailbox, nickname: name)
        } catch {
            guard !error.isPostalCancellation else { return }
            saveError = error.postalLoadFailure.message
        }
    }
}

#Preview("Ask") {
    NavigationStack {
        OnboardingDestinationStep(store: .preview(step: .askDestination))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    OnboardingSkipMenu(onSkip: {})
                }
            }
    }
}

#Preview("Save pending") {
    NavigationStack {
        OnboardingDestinationStep(
            store: .preview(step: .askDestination),
            pendingMailbox: PreviewData.destinationMailboxes[0],
            nickname: "Alex"
        )
    }
}
