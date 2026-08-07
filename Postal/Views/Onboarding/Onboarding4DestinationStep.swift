import SwiftUI

struct OnboardingDestinationStep: View {
    @Bindable var store: OnboardingStore
    let api: APIClient

    @State private var showPicker = false
    @State private var pendingMailbox: MailboxSummary?
    @State private var nickname = ""
    @State private var isSaving = false
    @State private var saveError: String?

    init(
        store: OnboardingStore,
        api: APIClient = AppServices.api,
        pendingMailbox: MailboxSummary? = nil,
        nickname: String = ""
    ) {
        self.store = store
        self.api = api
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
