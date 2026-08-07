import SwiftUI

struct OnboardingLetterStep: View {
    @Bindable var store: OnboardingStore
    let api: APIClient
    let pendingCapsules: PendingTimeCapsuleStoring
    private let loadsOnAppear: Bool

    private enum DestinationChoice: Equatable {
        case selfMailbox
        case saved(MailboxSummary)
    }

    enum CompletionKind: Equatable {
        case sent(preset: SchedulePreset, scheduledAt: Date?)
        case needsStamps
    }

    @State private var choice: DestinationChoice = .selfMailbox
    @State private var selectedPreset: SchedulePreset = .oneMonth
    @State private var showComposer = false
    @State private var completion: CompletionKind?
    @State private var sealedCapsuleID: UUID?
    @State private var limits: LetterLimits?
    @State private var originMailbox: MailboxSummary?
    @State private var loadError: String?
    @State private var isSending = false

    init(
        store: OnboardingStore,
        api: APIClient = AppServices.api,
        pendingCapsules: PendingTimeCapsuleStoring = AppServices.pendingTimeCapsules,
        loadsOnAppear: Bool = true,
        previewOrigin: MailboxSummary? = nil,
        previewLimits: LetterLimits? = nil,
        previewCompletion: CompletionKind? = nil,
        previewPreset: SchedulePreset = .oneMonth
    ) {
        self.store = store
        self.api = api
        self.pendingCapsules = pendingCapsules
        self.loadsOnAppear = loadsOnAppear
        _originMailbox = State(initialValue: previewOrigin)
        _limits = State(initialValue: previewLimits)
        _completion = State(initialValue: previewCompletion)
        _selectedPreset = State(initialValue: previewPreset)
        if let saved = store.progress?.savedDestination {
            _choice = State(initialValue: .saved(saved))
        }
    }

    var body: some View {
        Group {
            if let completion {
                completionView(completion)
            } else {
                intro
            }
        }
        .navigationTitle("Letter")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showComposer) {
            LetterTextComposerView(
                limits: limits,
                onContinue: { text in
                    Task { await sendCapsule(text: text) }
                }
            )
            .disabled(isSending)
            .overlay {
                if isSending {
                    ProgressView(PromoText.onboardingLetterSending)
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .task {
            guard loadsOnAppear else { return }
            await loadContext()
        }
    }

    private var intro: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OnboardingStepHeader(
                    title: PromoText.onboardingLetterTitle,
                    bodyText: PromoText.onboardingLetterBody
                )

                if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Send to")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal)

                    destinationPicker
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(PromoText.onboardingLetterOpenAfter)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal)

                    schedulePicker
                }
            }
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingBottomActions {
                Button {
                    showComposer = true
                } label: {
                    Text("Write letter")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(originMailbox == nil && store.progress?.originMailboxID == nil)
            }
        }
    }

    @ViewBuilder
    private var destinationPicker: some View {
        VStack(spacing: 0) {
            Button {
                choice = .selfMailbox
            } label: {
                HStack {
                    Label(PromoText.onboardingLetterToSelf, systemImage: "tray")
                    Spacer()
                    if choice == .selfMailbox {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)

            if let saved = store.progress?.savedDestination {
                Divider().padding(.leading)
                Button {
                    choice = .saved(saved)
                } label: {
                    HStack {
                        Label(
                            store.progress?.savedDestinationNickname ?? saved.pickerLabel,
                            systemImage: "person.crop.circle"
                        )
                        Spacer()
                        if case .saved(let m) = choice, m.id == saved.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var schedulePicker: some View {
        VStack(spacing: 0) {
            ForEach(SchedulePreset.allCases, id: \.self) { preset in
                if preset != SchedulePreset.allCases.first {
                    Divider().padding(.leading)
                }
                Button {
                    selectedPreset = preset
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PromoText.sendTimingPreset(preset))
                            Text(PromoText.sendTimingPresetDetail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedPreset == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func completionView(_ kind: CompletionKind) -> some View {
        ContentUnavailableView {
            switch kind {
            case .sent:
                Label(PromoText.onboardingLetterSentTitle, systemImage: "envelope.open.fill")
            case .needsStamps:
                Label(PromoText.onboardingLetterNeedsStampsTitle, systemImage: "envelope.badge")
            }
        } description: {
            switch kind {
            case let .sent(preset, scheduledAt):
                Text(PromoText.onboardingLetterSentBody(preset: preset, scheduledAt: scheduledAt))
            case .needsStamps:
                Text(PromoText.onboardingLetterNeedsStampsBody)
            }
        } actions: {
            Button("Continue") {
                switch kind {
                case .sent:
                    store.recordLetterStepFinished()
                case .needsStamps:
                    if let sealedCapsuleID {
                        store.recordPendingTimeCapsule(id: sealedCapsuleID)
                    } else {
                        store.recordLetterStepFinished()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @MainActor
    private func loadContext() async {
        do {
            async let mailboxesTask = api.listOwnedMailboxes()
            async let limitsTask = api.getLimits()
            let mailboxes = try await mailboxesTask
            limits = try? await limitsTask

            if let id = store.progress?.originMailboxID,
               let match = mailboxes.first(where: { $0.id == id }) {
                originMailbox = match
            } else if let first = mailboxes.first {
                originMailbox = first
                store.skipClaimIfNeeded(ownedMailboxes: mailboxes)
            }

            if let saved = store.progress?.savedDestination {
                choice = .saved(saved)
            } else {
                choice = .selfMailbox
            }
        } catch {
            guard !error.isPostalCancellation else { return }
            loadError = error.postalLoadFailure.message
        }
    }

    @MainActor
    private func sendCapsule(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSending else { return }

        let originID = originMailbox?.id ?? store.progress?.originMailboxID
        let destination: MailboxSummary?
        let isSelf: Bool

        switch choice {
        case .selfMailbox:
            destination = originMailbox ?? store.progress.flatMap { progress in
                guard let id = progress.originMailboxID else { return nil }
                return MailboxSummary(
                    id: id,
                    postOfficeID: id.postOfficeID,
                    postOfficeName: nil,
                    label: progress.originMailboxLabel ?? "My mailbox",
                    ownerUserID: nil,
                    owned: true
                )
            }
            isSelf = true
        case .saved(let mailbox):
            destination = mailbox
            isSelf = false
        }

        guard let destination, let originID else {
            loadError = "Choose a destination mailbox first."
            showComposer = false
            return
        }

        let origin = originMailbox ?? MailboxSummary(
            id: originID,
            postOfficeID: originID.postOfficeID,
            postOfficeName: nil,
            label: store.progress?.originMailboxLabel ?? "My mailbox",
            ownerUserID: nil,
            owned: true
        )

        let capsule = PendingTimeCapsule(
            originMailboxID: originID,
            destinationMailboxID: destination.id,
            destinationLabel: isSelf
                ? (originMailbox?.label ?? store.progress?.originMailboxLabel ?? "My mailbox")
                : (store.progress?.savedDestinationNickname ?? destination.pickerLabel),
            letterText: trimmed,
            isSelfAddressed: isSelf,
            schedulePreset: selectedPreset
        )
        pendingCapsules.save(capsule)
        sealedCapsuleID = capsule.id

        isSending = true
        loadError = nil
        defer { isSending = false }

        do {
            let request = CreateShipmentRequest(
                origin: origin,
                destination: destination,
                letter: .plain(trimmed),
                schedule: .preset(selectedPreset)
            )
            let response = try await api.createShipment(request)
            pendingCapsules.delete(id: capsule.id)
            sealedCapsuleID = nil
            showComposer = false
            completion = .sent(
                preset: selectedPreset,
                scheduledAt: response.scheduledDeliveryAt ?? selectedPreset.deliveryDate()
            )
        } catch {
            guard !error.isPostalCancellation else { return }
            showComposer = false
            if case let APIError.httpStatus(code, _, _) = error, code == 402 {
                completion = .needsStamps
            } else {
                loadError = error.postalLoadFailure.message
            }
        }
    }
}

#Preview("To self") {
    NavigationStack {
        OnboardingLetterStep(
            store: .preview(step: .composeLetter),
            pendingCapsules: PreviewPendingTimeCapsuleStore(),
            loadsOnAppear: false,
            previewOrigin: PreviewData.ownedMailboxes[0],
            previewLimits: .preview
        )
    }
}

#Preview("With saved destination") {
    NavigationStack {
        OnboardingLetterStep(
            store: .preview(
                step: .composeLetter,
                savedDestination: PreviewData.destinationMailboxes[0],
                savedDestinationNickname: "Alex"
            ),
            pendingCapsules: PreviewPendingTimeCapsuleStore(),
            loadsOnAppear: false,
            previewOrigin: PreviewData.ownedMailboxes[0],
            previewLimits: .preview
        )
    }
}

#Preview("Sent confirm") {
    NavigationStack {
        OnboardingLetterStep(
            store: .preview(step: .composeLetter),
            pendingCapsules: PreviewPendingTimeCapsuleStore(),
            loadsOnAppear: false,
            previewOrigin: PreviewData.ownedMailboxes[0],
            previewCompletion: .sent(preset: .oneMonth, scheduledAt: SchedulePreset.oneMonth.deliveryDate())
        )
    }
}

#Preview("Needs stamps") {
    NavigationStack {
        OnboardingLetterStep(
            store: .preview(step: .composeLetter),
            pendingCapsules: PreviewPendingTimeCapsuleStore(),
            loadsOnAppear: false,
            previewOrigin: PreviewData.ownedMailboxes[0],
            previewCompletion: .needsStamps
        )
    }
}
