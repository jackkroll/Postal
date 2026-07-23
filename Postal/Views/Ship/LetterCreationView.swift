import PencilKit
import SwiftUI

enum LetterCreationPhase: String, Codable, Equatable {
    case overview
    case destination
    case returnAddress
    case letterType
    case compose
    case stamp
    case sending
    case sent
}

enum LetterComposeKind: String, Codable, Equatable {
    case text
    case drawing
}

struct LetterCamera: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    static let identity = LetterCamera()
}

enum LetterCreationMotion {
    static let soft = Animation.spring(response: 0.9, dampingFraction: 0.9)
    static let letterSlide = Animation.spring(response: 0.55, dampingFraction: 0.78)
    static let envelope = Animation.spring(response: 0.95, dampingFraction: 0.9)
    static let camera = Animation.spring(response: 0.9, dampingFraction: 0.9)
}

enum LetterSheetPlacement: Equatable {
    case tucked
    case revealed
}

struct LetterCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Router.self) private var router: Router?
    @State private var viewmodel: ViewModel
    @State private var pendingClaimBoxNavigation = false
    @FocusState private var isComposerFocused: Bool
    private let loadsOnAppear: Bool

    init(
        viewmodel: ViewModel = ViewModel(api: AppServices.api),
        loadsOnAppear: Bool = true
    ) {
        _viewmodel = State(initialValue: viewmodel)
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                LetterCreationCaption(viewmodel: viewmodel)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .zIndex(3)
                
                LetterCreationStage(
                    viewmodel: viewmodel,
                    isComposerFocused: $isComposerFocused
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                LetterCreationChrome(viewmodel: viewmodel, isComposerFocused: $isComposerFocused)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color(.systemGroupedBackground))
                    .zIndex(3)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loadsOnAppear else { return }
            await viewmodel.loadMailboxes()
            await viewmodel.beginGuidedFlow()
        }
        .onChange(of: viewmodel.phase) { _, newPhase in
            isComposerFocused = newPhase == .compose
            viewmodel.refreshCamera(animated: true)
            viewmodel.scheduleAutosave()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                viewmodel.saveDraftNow()
            }
        }
        .onDisappear {
            viewmodel.saveDraftNow()
        }
        .sheet(isPresented: $viewmodel.isDestinationPickerPresented) {
            DestinationMailboxPickerSheet(api: viewmodel.api) { mailbox in
                viewmodel.selectDestination(mailbox)
            }
        }
        .sheet(isPresented: $viewmodel.isOriginPickerPresented, onDismiss: {
            guard pendingClaimBoxNavigation else { return }
            pendingClaimBoxNavigation = false
            router?.push(.claimBox)
        }) {
            OriginMailboxPickerSheet(
                mailboxes: viewmodel.ownedMailboxes,
                selectedID: viewmodel.selectedOriginMailboxID,
                isLoading: viewmodel.isLoadingMailboxes,
                onSelect: { viewmodel.selectOrigin($0) },
                onClaimMailbox: {
                    pendingClaimBoxNavigation = true
                    viewmodel.isOriginPickerPresented = false
                }
            )
        }
        .navigationDestination(isPresented: $viewmodel.isDrawingComposerPresented) {
            CanvasView(
                initialDrawingData: viewmodel.drawingData,
                draftSaveStatus: viewmodel.draftSaveStatus,
                onDrawingChange: { data in
                    viewmodel.updateInProgressDrawing(data)
                },
                onContinue: { data in
                    viewmodel.finishDrawing(data)
                }
            )
        }
        .onChange(of: viewmodel.isDrawingComposerPresented) { _, isPresented in
            if !isPresented {
                viewmodel.handleDrawingComposerDismissed()
            }
        }
        .alert("Letter Sent", isPresented: $viewmodel.showSuccess) {
            Button("Done") { dismiss() }
            if let tracking = viewmodel.createdTrackingNumber {
                Button("Copy Tracking") {
                    UIPasteboard.general.string = tracking
                }
            }
        } message: {
            if let tracking = viewmodel.createdTrackingNumber {
                Text("Tracking number: \(tracking)")
            } else {
                Text("Your letter is on its way.")
            }
        }
        .alert("Couldn't Send", isPresented: Binding(
            get: { viewmodel.sendErrorMessage != nil },
            set: { if !$0 { viewmodel.sendErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewmodel.retryStampPhase()
            }
        } message: {
            Text(viewmodel.sendErrorMessage ?? "")
        }
        .alert("Couldn't Load Mailboxes", isPresented: Binding(
            get: { viewmodel.loadErrorMessage != nil },
            set: { if !$0 { viewmodel.loadErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                Task { await viewmodel.loadMailboxes() }
            }
        } message: {
            Text(viewmodel.loadErrorMessage ?? "")
        }
    }
}

// MARK: - Caption (phase copy only)

private struct LetterCreationCaption: View {
    @Bindable var viewmodel: LetterCreationView.ViewModel

    var body: some View {
        VStack(spacing: 4) {
            Text(viewmodel.phaseTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            if !viewmodel.phaseSubtitle.isEmpty {
                Text(viewmodel.phaseSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if viewmodel.phase == .compose, viewmodel.draftSaveStatus != .hidden {
                DraftSaveStatusLabel(status: viewmodel.draftSaveStatus)
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44, alignment: .center)
        .animation(LetterCreationMotion.soft, value: viewmodel.phase)
        .animation(LetterCreationMotion.soft, value: viewmodel.draftSaveStatus)
    }
}

// MARK: - Stage (stable letter + envelope tree)

private struct LetterCreationStage: View {
    @Bindable var viewmodel: LetterCreationView.ViewModel
    @FocusState.Binding var isComposerFocused: Bool

    private static let stageMaxWidth: CGFloat = 500
    private static let stageHorizontalInset: CGFloat = 32

    var body: some View {
        // One GeometryReader for available space. Stage fills the viewport (no fixed aspect).
        GeometryReader { viewport in
            let stageSize = Self.stageSize(fitting: viewport.size)

            stableStage(size: stageSize)
                .frame(width: stageSize.width, height: stageSize.height)
                .backgroundPreferenceValue(LetterRegionAnchorsPreferenceKey.self) { anchors in
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: LetterRegionFramesPreferenceKey.self,
                            value: anchors.mapValues { proxy[$0] }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .scaleEffect(viewmodel.camera.scale, anchor: .center)
                .offset(viewmodel.camera.offset)
                .clipped()
                .onAppear {
                    viewmodel.updateViewportSize(viewport.size)
                    viewmodel.updateStageSize(stageSize)
                }
                .onChange(of: viewport.size) { _, newSize in
                    viewmodel.updateViewportSize(newSize)
                    viewmodel.updateStageSize(Self.stageSize(fitting: newSize))
                }
        }
        .onPreferenceChange(LetterRegionFramesPreferenceKey.self) { frames in
            // Cache only — never animate camera from preference callbacks.
            viewmodel.updateRegionFrames(frames)
        }
    }

    /// Fill the viewport height; width is inset and optionally capped.
    private static func stageSize(fitting viewport: CGSize) -> CGSize {
        let availableWidth = max(viewport.width - stageHorizontalInset, 0)
        return CGSize(
            width: min(availableWidth, stageMaxWidth),
            height: max(viewport.height, 0)
        )
    }

    /// One letter + one envelope for the lifetime of the stage; transforms only.
    private func stableStage(size: CGSize) -> some View {
        let revealed = viewmodel.letterPlacement == .revealed
        // Keep both objects inside the stage bounds so `.clipped()` doesn't hide the letter.
        let envelopeHeight = size.height * (revealed ? 0.30 : 0.72)
        let letterHeight = size.height * (revealed ? 0.78 : 0.48)
        let letterWidth = size.width - 24
        // Pin content to the top of the stage (small tuck inset when letter is inside).
        let envelopeOffsetY: CGFloat = revealed ? letterHeight - 28 : 12
        let letterOffsetY: CGFloat = revealed ? 4 : envelopeOffsetY + envelopeHeight * 0.08

        return ZStack(alignment: .top) {
            LetterSheetHost(
                viewmodel: viewmodel,
                isComposerFocused: $isComposerFocused,
                isComposing: viewmodel.phase == .compose && revealed
            )
            .frame(width: letterWidth, height: letterHeight)
            .frame(maxWidth: .infinity, alignment: .center)
            .scaleEffect(revealed ? 1 : 0.92, anchor: .bottom)
            .opacity(viewmodel.envelopeVisible ? (revealed ? 1 : 0.4) : 0)
            .offset(y: letterOffsetY)
            .zIndex(revealed ? 2 : 0)
            .allowsHitTesting(revealed)
            .animation(LetterCreationMotion.letterSlide, value: viewmodel.letterPlacement)
            .animation(LetterCreationMotion.envelope, value: viewmodel.envelopeVisible)

            ShippingEnvelopeView(
                destination: viewmodel.selectedDestinationMailbox,
                origin: viewmodel.selectedOriginMailbox,
                isStampApplied: viewmodel.isStampApplied,
                isStampInteractive: viewmodel.phase == .stamp && !viewmodel.isSending,
                highlightedRegion: viewmodel.highlightedRegion,
                isDimmed: revealed,
                onDestinationTap: {
                    guard viewmodel.phase == .destination else { return }
                    viewmodel.isDestinationPickerPresented = true
                },
                onOriginTap: {
                    guard viewmodel.phase == .returnAddress else { return }
                    viewmodel.isOriginPickerPresented = true
                },
                onStampTap: {
                    Task { await viewmodel.applyStampAndSend() }
                }
            )
            .frame(width: size.width, height: envelopeHeight)
            .offset(y: envelopeOffsetY)
            .opacity(viewmodel.envelopeVisible ? 1 : 0)
            .offset(y: viewmodel.envelopeVisible ? 0 : 16)
            .zIndex(1)
            .allowsHitTesting(viewmodel.envelopeVisible && !revealed)
            .animation(LetterCreationMotion.envelope, value: viewmodel.envelopeVisible)
            .animation(LetterCreationMotion.letterSlide, value: viewmodel.letterPlacement)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Owns `letterText` observation so keystrokes don't invalidate the stage chrome/envelope.
private struct LetterSheetHost: View {
    @Bindable var viewmodel: LetterCreationView.ViewModel
    @FocusState.Binding var isComposerFocused: Bool
    let isComposing: Bool

    var body: some View {
        LetterSheetView(
            isComposing: isComposing,
            letterText: viewmodel.letterText,
            drawingAttached: viewmodel.composeKind == .drawing && viewmodel.drawingData != nil,
            isHighlighted: viewmodel.highlightedRegion == .body,
            letterTextBinding: $viewmodel.letterText,
            isComposerFocused: $isComposerFocused
        )
        .onChange(of: viewmodel.letterText) { _, newValue in
            viewmodel.recomputeLetterMetrics(from: newValue)
            viewmodel.scheduleDebouncedAutosave()
        }
    }
}

// MARK: - Chrome

private struct LetterCreationChrome: View {
    @Bindable var viewmodel: LetterCreationView.ViewModel
    @FocusState.Binding var isComposerFocused: Bool

    var body: some View {
        switch viewmodel.phase {
        case .compose:
            HStack(spacing: 12) {
                if viewmodel.canGoBack {
                    Button {
                        isComposerFocused = false
                        viewmodel.enqueueBack()
                    } label: {
                        Label("Back", systemImage: "chevron.backward")
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                if viewmodel.canAdvance {
                    Button {
                        isComposerFocused = false
                        viewmodel.enqueueForward()
                    } label: {
                        Label("Continue", systemImage: "chevron.forward")
                            .labelStyle(SwappedLabelStyle())
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text(viewmodel.letterIsBlank ? "Write something to continue" : " ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(1)
                }
            }
        case .letterType:
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        viewmodel.selectComposeKind(.text)
                    } label: {
                        Label("Write", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewmodel.selectComposeKind(.drawing)
                    } label: {
                        Label("Draw", systemImage: "pencil.tip.crop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if viewmodel.canGoBack {
                    Button {
                        viewmodel.enqueueBack()
                    } label: {
                        Label("Back", systemImage: "chevron.backward")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .stamp:
            stepNavigationRow(centerPrompt: "Tap the stamp to send", showContinue: false)
        case .sending:
            ProgressView("Sending…")
                .frame(maxWidth: .infinity)
        case .returnAddress:
            if viewmodel.ownedMailboxes.isEmpty && !viewmodel.isLoadingMailboxes {
                NavigationLink(value: ViewRoute.claimBox) {
                    Text("Claim a Mailbox")
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            } else {
                stepNavigationRow(centerPrompt: nil, showContinue: true)
            }
        case .destination:
            stepNavigationRow(centerPrompt: nil, showContinue: true)
        case .overview:
            ProgressView()
                .frame(maxWidth: .infinity)
        default:
            Color.clear
        }
    }

    private func stepNavigationRow(centerPrompt: String?, showContinue: Bool) -> some View {
        HStack(spacing: 12) {
            Group {
                if viewmodel.canGoBack {
                    Button {
                        viewmodel.enqueueBack()
                    } label: {
                        Label("Back", systemImage: "chevron.backward")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Spacer(minLength: 0)

            Group {
                if showContinue {
                    Button {
                        viewmodel.enqueueForward()
                    } label: {
                        Label("Continue", systemImage: "chevron.forward")
                            .labelStyle(SwappedLabelStyle())
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewmodel.canAdvance)
                }
            }
        }
    }
}

// MARK: - Origin picker

private struct OriginMailboxPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mailboxes: [MailboxSummary]
    let selectedID: MailboxID?
    let isLoading: Bool
    let onSelect: (MailboxSummary) -> Void
    let onClaimMailbox: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your mailboxes…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if mailboxes.isEmpty {
                    ContentUnavailableView {
                        Label("No Mailboxes", systemImage: "tray")
                    } description: {
                        Text("Claim a mailbox before sending letters.")
                    } actions: {
                        Button("Claim a Mailbox") {
                            onClaimMailbox()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(mailboxes) { mailbox in
                        Button {
                            onSelect(mailbox)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mailbox.label)
                                        .foregroundStyle(.primary)
                                    Text(mailbox.locationLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if mailbox.id == selectedID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - ViewModel

extension LetterCreationView {
    @Observable
    class ViewModel {
        static let maxLetterBytes = 65_536

        private static let byteCountFormatter: ByteCountFormatter = {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter
        }()

        let api: APIClient
        let drafts: DraftLetterStoring
        let draftID: UUID

        var phase: LetterCreationPhase = .overview
        var camera: LetterCamera = .identity
        var envelopeVisible = false
        var letterPlacement: LetterSheetPlacement = .tucked

        var ownedMailboxes: [MailboxSummary] = []
        var selectedOriginMailboxID: MailboxID?
        var selectedDestinationMailbox: MailboxSummary?
        var isDestinationPickerPresented = false
        var isOriginPickerPresented = false
        var isLoadingMailboxes = false
        var loadErrorMessage: String?

        var letterText = ""
        /// Cached metrics so chrome doesn't re-scan UTF-8 / trim on every read path unnecessarily.
        private(set) var letterByteCount = 0
        private(set) var letterIsBlank = true

        var composeKind: LetterComposeKind?
        var drawingData: Data?
        var isDrawingComposerPresented = false
        var draftSaveStatus: DraftSaveStatus = .hidden

        var isStampApplied = false
        var isSending = false
        var sendErrorMessage: String?
        var createdTrackingNumber: String?
        var showSuccess = false

        private(set) var viewportSize: CGSize = .zero
        private(set) var stageSize: CGSize = .zero
        private(set) var regionFrames: [LetterCreationRegion: CGRect] = [:]

        private var suppressCameraRefresh = false
        private var transitionTask: Task<Void, Never>?
        private var autosaveTask: Task<Void, Never>?
        private var isResumingDraft = false
        private var draftDeleted = false
        private var hasPersistedDraft = false

        init(
            api: APIClient,
            drafts: DraftLetterStoring = AppServices.letterDrafts,
            origin: MailboxSummary? = nil,
            destination: MailboxSummary? = nil,
            draftID: UUID? = nil
        ) {
            self.api = api
            self.drafts = drafts
            if let draftID, let draft = drafts.load(id: draftID) {
                self.draftID = draft.id
                isResumingDraft = true
                hasPersistedDraft = true
                draftSaveStatus = .saved
                phase = Self.clampedPhase(draft.phase, composeKind: draft.composeKind)
                composeKind = draft.composeKind
                selectedOriginMailboxID = draft.originMailboxID
                selectedDestinationMailbox = draft.destination
                letterText = draft.letterText
                letterByteCount = draft.letterText.utf8.count
                letterIsBlank = draft.letterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if draft.hasDrawing {
                    drawingData = drafts.loadDrawingData(id: draft.id)
                }
                letterPlacement = phase == .compose ? .revealed : .tucked
            } else {
                self.draftID = draftID ?? UUID()
                if let origin {
                    ownedMailboxes = [origin]
                    selectedOriginMailboxID = origin.id
                }
                selectedDestinationMailbox = destination
            }
        }

        private static func clampedPhase(
            _ phase: LetterCreationPhase,
            composeKind: LetterComposeKind?
        ) -> LetterCreationPhase {
            switch phase {
            case .sending, .sent:
                return .stamp
            case .overview:
                switch composeKind {
                case .drawing:
                    return .stamp
                case .text:
                    return .compose
                case nil:
                    return .destination
                }
            default:
                return phase
            }
        }

        /// Destination, content, or compose choice — not origin alone (avoids empty drafts from auto-selected From).
        private var shouldPersistDraft: Bool {
            selectedDestinationMailbox != nil
                || composeKind != nil
                || !letterIsBlank
                || !(drawingData?.isEmpty ?? true)
        }

        func scheduleDebouncedAutosave() {
            guard !draftDeleted, shouldPersistDraft || hasPersistedDraft else { return }
            markDraftSaving()
            autosaveTask?.cancel()
            autosaveTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                saveDraftNow()
            }
        }

        func scheduleAutosave() {
            guard !draftDeleted, shouldPersistDraft || hasPersistedDraft else { return }
            markDraftSaving()
            autosaveTask?.cancel()
            autosaveTask = Task { @MainActor in
                saveDraftNow()
            }
        }

        func saveDraftNow() {
            guard !draftDeleted else { return }
            guard shouldPersistDraft || hasPersistedDraft else {
                draftSaveStatus = .hidden
                return
            }
            let persistedPhase: LetterCreationPhase
            switch phase {
            case .sending, .sent, .overview:
                persistedPhase = Self.clampedPhase(phase, composeKind: composeKind)
            default:
                persistedPhase = phase
            }
            let draft = LetterDraft(
                id: draftID,
                updatedAt: .now,
                phase: persistedPhase,
                composeKind: composeKind,
                originMailboxID: selectedOriginMailboxID,
                destination: selectedDestinationMailbox,
                letterText: letterText,
                hasDrawing: !(drawingData?.isEmpty ?? true)
            )
            drafts.save(draft, drawingData: drawingData)
            hasPersistedDraft = true
            markDraftSaved()
        }

        func deleteDraft() {
            draftDeleted = true
            autosaveTask?.cancel()
            draftSaveStatus = .hidden
            drafts.delete(id: draftID)
        }

        /// Persist strokes while the drawing composer is open.
        @MainActor
        func updateInProgressDrawing(_ data: Data) {
            let isEmpty = data.isEmpty || ((try? PKDrawing(data: data))?.strokes.isEmpty ?? true)
            drawingData = isEmpty ? nil : data
            if !isEmpty {
                composeKind = .drawing
            } else if isDrawingComposerPresented {
                // Keep draw mode while the canvas is open so an empty clear still autosaves state.
                composeKind = .drawing
            }
            scheduleDebouncedAutosave()
        }

        private func markDraftSaving() {
            guard shouldPersistDraft || hasPersistedDraft else { return }
            if draftSaveStatus != .saving {
                draftSaveStatus = .saving
            }
        }

        private func markDraftSaved() {
            draftSaveStatus = .saved
        }

        var selectedOriginMailbox: MailboxSummary? {
            guard let selectedOriginMailboxID else { return nil }
            return ownedMailboxes.first { $0.id == selectedOriginMailboxID }
        }

        var isOverByteLimit: Bool {
            letterByteCount > Self.maxLetterBytes
        }

        var canSend: Bool {
            guard selectedOriginMailbox != nil,
                  selectedDestinationMailbox != nil,
                  !isSending
            else { return false }

            switch composeKind {
            case .text:
                return !letterIsBlank && !isOverByteLimit
            case .drawing:
                guard let drawingData, !drawingData.isEmpty else { return false }
                return drawingData.count <= Self.maxLetterBytes
            case nil:
                return false
            }
        }

        var canAdvance: Bool {
            switch phase {
            case .destination:
                return selectedDestinationMailbox != nil
            case .returnAddress:
                return selectedOriginMailbox != nil
            case .compose:
                return canSend
            default:
                return false
            }
        }

        var canGoBack: Bool {
            switch phase {
            case .returnAddress, .letterType, .compose, .stamp:
                return true
            default:
                return false
            }
        }

        var byteCountLabel: String {
            let current = Self.byteCountFormatter.string(fromByteCount: Int64(letterByteCount))
            let max = Self.byteCountFormatter.string(fromByteCount: Int64(Self.maxLetterBytes))
            return "\(current) / \(max)"
        }

        var highlightedRegion: LetterCreationRegion? {
            switch phase {
            case .destination: return .destination
            case .returnAddress: return .returnAddress
            case .compose: return .body
            case .stamp, .sending: return .stamp
            default: return nil
            }
        }

        var phaseTitle: String {
            switch phase {
            case .overview: return "New Letter"
            case .destination: return "Destination"
            case .returnAddress: return "Return Address"
            case .letterType: return "Letter Style"
            case .compose: return "Letter"
            case .stamp: return "Send"
            case .sending: return "Sending"
            case .sent: return "Sent"
            }
        }

        var phaseSubtitle: String {
            switch phase {
            case .overview:
                return ""
            case .destination:
                return "Choose where this letter goes."
            case .returnAddress:
                return "Choose which mailbox to send from."
            case .letterType:
                return "Write a letter or draw one."
            case .compose:
                return "Write your letter, then continue."
            case .stamp:
                return "Tap the stamp to send."
            case .sending:
                return "Sending…"
            case .sent:
                return createdTrackingNumber.map { "Tracking number \($0)" } ?? "Your letter is on its way."
            }
        }

        func recomputeLetterMetrics(from text: String) {
            letterByteCount = text.utf8.count
            letterIsBlank = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func updateViewportSize(_ size: CGSize) {
            guard size != viewportSize else { return }
            viewportSize = size
        }

        func updateStageSize(_ size: CGSize) {
            guard size != stageSize else { return }
            stageSize = size
            refreshCamera(animated: false)
        }

        func updateRegionFrames(_ frames: [LetterCreationRegion: CGRect]) {
            guard !suppressCameraRefresh else { return }
            guard frames != regionFrames else { return }
            let active = highlightedRegion
            let previousActive = active.flatMap { regionFrames[$0] }
            regionFrames = frames
            // Reframe when the phase’s target region settles (e.g. destination text after pick).
            if let active,
               let frame = frames[active],
               frame.width > 0, frame.height > 0,
               frame != previousActive {
                refreshCamera(animated: true)
            }
        }

        func loadMailboxes() async {
            isLoadingMailboxes = true
            loadErrorMessage = nil
            defer { isLoadingMailboxes = false }

            do {
                ownedMailboxes = try await api.listOwnedMailboxes()
                if selectedOriginMailboxID == nil, ownedMailboxes.count == 1 {
                    selectedOriginMailboxID = ownedMailboxes[0].id
                } else if let selectedOriginMailboxID,
                          !ownedMailboxes.contains(where: { $0.id == selectedOriginMailboxID }) {
                    self.selectedOriginMailboxID = nil
                }
            } catch {
                loadErrorMessage = error.localizedDescription
            }
        }

        @MainActor
        func beginGuidedFlow() async {
            withAnimation(LetterCreationMotion.envelope) {
                envelopeVisible = true
                letterPlacement = phase == .compose ? .revealed : .tucked
            }

            if isResumingDraft {
                isResumingDraft = false
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                refreshCamera(animated: true)
                return
            }

            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled, phase == .overview else { return }

            let nextPhase: LetterCreationPhase
            if selectedDestinationMailbox != nil, selectedOriginMailbox != nil {
                nextPhase = .letterType
            } else if selectedDestinationMailbox != nil {
                nextPhase = .returnAddress
            } else {
                nextPhase = .destination
            }
            await transition(to: nextPhase, zoomOutFirst: false)
        }

        func selectDestination(_ mailbox: MailboxSummary) {
            selectedDestinationMailbox = mailbox
            isDestinationPickerPresented = false
            scheduleAutosave()
            Task { @MainActor in
                // Wait for sheet dismiss + address layout before reframing.
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled, phase == .destination else { return }
                refreshCamera(animated: true)
            }
        }

        func selectOrigin(_ mailbox: MailboxSummary) {
            selectedOriginMailboxID = mailbox.id
            isOriginPickerPresented = false
            scheduleAutosave()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled, phase == .returnAddress else { return }
                refreshCamera(animated: true)
            }
        }

        @MainActor
        func enqueueForward() {
            transitionTask?.cancel()
            transitionTask = Task { @MainActor in await goForward() }
        }

        @MainActor
        func enqueueBack() {
            transitionTask?.cancel()
            transitionTask = Task { @MainActor in await goBack() }
        }

        @MainActor
        func goForward() async {
            switch phase {
            case .destination:
                guard selectedDestinationMailbox != nil else { return }
                await transition(to: .returnAddress, zoomOutFirst: true)
            case .returnAddress:
                guard selectedOriginMailbox != nil else { return }
                await transition(to: .letterType, zoomOutFirst: true)
            case .compose:
                guard canSend else { return }
                await transition(to: .stamp, zoomOutFirst: true)
            default:
                break
            }
        }

        @MainActor
        func goBack() async {
            switch phase {
            case .returnAddress:
                await transition(to: .destination, zoomOutFirst: true)
            case .letterType:
                composeKind = nil
                scheduleAutosave()
                await transition(to: .returnAddress, zoomOutFirst: true)
            case .compose:
                await transition(to: .letterType, zoomOutFirst: true)
            case .stamp:
                isStampApplied = false
                switch composeKind {
                case .drawing:
                    await transition(to: .letterType, zoomOutFirst: true)
                    isDrawingComposerPresented = true
                case .text:
                    await transition(to: .compose, zoomOutFirst: true)
                case nil:
                    await transition(to: .letterType, zoomOutFirst: true)
                }
            default:
                break
            }
        }

        @MainActor
        func selectComposeKind(_ kind: LetterComposeKind) {
            composeKind = kind
            switch kind {
            case .text:
                drawingData = nil
                scheduleAutosave()
                transitionTask?.cancel()
                transitionTask = Task { @MainActor in
                    await transition(to: .compose, zoomOutFirst: true)
                }
            case .drawing:
                letterText = ""
                recomputeLetterMetrics(from: "")
                scheduleAutosave()
                isDrawingComposerPresented = true
            }
        }

        @MainActor
        func finishDrawing(_ data: Data) {
            drawingData = data
            composeKind = .drawing
            isDrawingComposerPresented = false
            scheduleAutosave()
            transitionTask?.cancel()
            transitionTask = Task { @MainActor in
                await transition(to: .stamp, zoomOutFirst: false)
            }
        }

        @MainActor
        func handleDrawingComposerDismissed() {
            // Popped without continuing — stay on type selection unless a drawing was saved.
            guard phase == .letterType || phase == .stamp else { return }
            if drawingData == nil {
                composeKind = nil
                scheduleAutosave()
            }
        }

        @MainActor
        func applyStampAndSend() async {
            guard phase == .stamp, canSend, !isStampApplied, !isSending else { return }

            isStampApplied = true
            isSending = true

            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else {
                isSending = false
                return
            }
            phase = .sending
            await send()
        }

        func retryStampPhase() {
            isStampApplied = false
            isSending = false
            phase = .stamp
            sendErrorMessage = nil
            withAnimation(LetterCreationMotion.soft) {
                envelopeVisible = true
                letterPlacement = .tucked
                camera = .identity
            }
        }

        @MainActor
        func refreshCamera(animated: Bool) {
            guard !suppressCameraRefresh else { return }
            guard viewportSize.width > 0, stageSize.width > 0 else { return }
            guard envelopeVisible else { return }

            let target = Self.camera(
                for: phase,
                viewportSize: viewportSize,
                stageSize: stageSize,
                regionFrames: regionFrames
            )
            guard target != camera else { return }

            if animated {
                withAnimation(LetterCreationMotion.camera) {
                    camera = target
                }
            } else {
                camera = target
            }
        }

        @MainActor
        private func transition(to newPhase: LetterCreationPhase, zoomOutFirst: Bool) async {
            if zoomOutFirst {
                suppressCameraRefresh = true
                withAnimation(LetterCreationMotion.camera) {
                    camera = .identity
                }
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else {
                    suppressCameraRefresh = false
                    return
                }
                suppressCameraRefresh = false
            }

            withAnimation(LetterCreationMotion.letterSlide) {
                phase = newPhase
                switch newPhase {
                case .compose:
                    letterPlacement = .revealed
                case .stamp, .sending, .destination, .returnAddress, .overview, .letterType:
                    letterPlacement = .tucked
                case .sent:
                    break
                }
            }

            // Wait for letter/envelope layout to settle before measuring & framing.
            try? await Task.sleep(for: .milliseconds(newPhase == .compose ? 380 : 160))
            guard !Task.isCancelled else { return }
            refreshCamera(animated: true)
        }

        @MainActor
        private func send() async {
            defer { isSending = false }

            guard let origin = selectedOriginMailbox,
                  let destination = selectedDestinationMailbox
            else {
                isStampApplied = false
                phase = .stamp
                return
            }

            sendErrorMessage = nil

            do {
                let response: ShipmentCreateResponse
                switch composeKind {
                case .text:
                    let request = CreateShipmentRequest(
                        origin: origin,
                        destination: destination,
                        letter: .plain(letterText.trimmingCharacters(in: .whitespacesAndNewlines))
                    )
                    response = try await api.createShipment(request)
                case .drawing:
                    guard let drawingData, !drawingData.isEmpty else {
                        isStampApplied = false
                        phase = .stamp
                        return
                    }
                    let request = CreateMultipartShipmentRequest(
                        origin: origin,
                        destination: destination,
                        letter: .pkDrawing(drawingData)
                    )
                    response = try await api.createShipmentMultipart(request)
                case nil:
                    isStampApplied = false
                    phase = .stamp
                    return
                }

                createdTrackingNumber = response.trackingNumber
                deleteDraft()
                phase = .sent
                withAnimation(LetterCreationMotion.envelope) {
                    camera = .identity
                    letterPlacement = .tucked
                    envelopeVisible = false
                }
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                showSuccess = true
            } catch {
                sendErrorMessage = error.localizedDescription
                isStampApplied = false
                phase = .stamp
                withAnimation(LetterCreationMotion.soft) {
                    envelopeVisible = true
                    letterPlacement = .tucked
                }
            }
        }

        static func camera(
            for phase: LetterCreationPhase,
            viewportSize: CGSize,
            stageSize: CGSize,
            regionFrames: [LetterCreationRegion: CGRect]
        ) -> LetterCamera {
            let region: LetterCreationRegion?
            let padding: CGFloat
            switch phase {
            case .overview, .sent, .letterType:
                return .identity
            case .destination:
                region = .destination
                padding = 1.55
            case .returnAddress:
                region = .returnAddress
                padding = 1.7
            case .compose:
                // Letter already fills the stage — zooming compresses the editor.
                return .identity
            case .stamp, .sending:
                region = .stamp
                padding = 2.4
            }

            guard let region,
                  let frame = regionFrames[region],
                  frame.width > 0, frame.height > 0
            else {
                return .identity
            }

            let scaleX = viewportSize.width / (frame.width * padding)
            let scaleY = viewportSize.height / (frame.height * padding)
            let scale = min(max(min(scaleX, scaleY), 1.05), 1.65)

            // Stage is top-centered in the viewport; camera transforms apply to that full viewport.
            let stageOrigin = CGPoint(
                x: (viewportSize.width - stageSize.width) / 2,
                y: 0
            )
            let regionCenterInViewport = CGPoint(
                x: stageOrigin.x + frame.midX,
                y: stageOrigin.y + frame.midY
            )
            let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)

            return LetterCamera(
                scale: scale,
                offset: CGSize(
                    width: (viewportCenter.x - regionCenterInViewport.x) * scale,
                    height: (viewportCenter.y - regionCenterInViewport.y) * scale
                )
            )
        }
    }
}

#Preview("Overview → Destination") {
    NavigationStack {
        LetterCreationView(viewmodel: .preview(phase: .destination), loadsOnAppear: false)
    }
    .environment(Router())
}

#Preview("Letter Style") {
    NavigationStack {
        LetterCreationView(viewmodel: .preview(phase: .letterType), loadsOnAppear: false)
    }
    .environment(Router())
}

#Preview("Compose") {
    NavigationStack {
        LetterCreationView(viewmodel: .preview(
            phase: .compose,
            selectedOriginMailbox: PreviewData.ownedMailboxes[0],
            selectedDestinationMailbox: PreviewData.destinationMailboxes[1],
            letterText: PreviewData.sampleLetterText,
            composeKind: .text
        ), loadsOnAppear: false)
    }
    .environment(Router())
}

#Preview("Stamp Ready") {
    NavigationStack {
        LetterCreationView(viewmodel: .preview(
            phase: .stamp,
            selectedOriginMailbox: PreviewData.ownedMailboxes[0],
            selectedDestinationMailbox: PreviewData.destinationMailboxes[1],
            letterText: PreviewData.sampleLetterText,
            composeKind: .text
        ), loadsOnAppear: false)
    }
    .environment(Router())
}

#Preview("No Mailboxes") {
    NavigationStack {
        LetterCreationView(viewmodel: .preview(
            phase: .returnAddress,
            ownedMailboxes: []
        ), loadsOnAppear: false)
    }
    .environment(Router())
}

struct SwappedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}
