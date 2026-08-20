import PencilKit
import SwiftUI

enum LetterCreationPhase: String, Codable, Equatable {
    case overview
    case destination
    case returnAddress
    /// Letter is revealed: write/draw options, then a preview of what was composed.
    case letterType
    /// Legacy inline composer step. Kept so older drafts still decode; clamped to `.letterType`.
    case compose
    case stamp
    case sending
    case sent
}

enum LetterComposeKind: String, Codable, Equatable {
    case text
    case drawing
}

/// Composers are full pages pushed from the letter, not inline stage states.
enum LetterComposerPage: String, Hashable {
    case write
    case draw

    init(_ kind: LetterComposeKind) {
        self = kind == .text ? .write : .draw
    }
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Router.self) private var router: Router?
    @State private var viewmodel: ViewModel
    @State private var pendingClaimBoxNavigation = false
    @State private var isPaywallPresented = false
    @State private var paywallSource: PaywallSource = .stampPhase
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

            // Laid out in the well between floating caption/chrome (does not ignore
            // safe area). Camera framing uses that same visible rect.
            LetterCreationStage(viewmodel: viewmodel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            LetterCreationCaption(
                viewmodel: viewmodel,
                onUpgrade: { presentPaywall(source: .stampPhase) }
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LetterCreationChrome(
                viewmodel: viewmodel,
                onUpgrade: { presentPaywall(source: .stampPhase) },
                onClaim: {
                    MonetizationAnalytics.claimTapped(source: .stampPhase)
                    Task { await viewmodel.claimStampAllowance() }
                }
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background {
                FloatingChromeScrim(edge: .bottom)
            }
        }
        .navigationTitle(viewmodel.phaseTitle)
        .letterCreationNavigationSubtitle(viewmodel.phaseSubtitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loadsOnAppear else { return }
            // Start composing immediately so offline devices can draft without waiting on the API.
            async let flow: Void = viewmodel.beginGuidedFlow()
            async let mailboxes: Void = viewmodel.loadMailboxes()
            async let entitlements: Void = viewmodel.refreshEntitlements()
            async let limits: Void = viewmodel.refreshLimits()
            _ = await (flow, mailboxes, entitlements, limits)
        }
        .onChange(of: viewmodel.phase) { _, _ in
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
                loadErrorMessage: viewmodel.loadErrorMessage,
                onSelect: { viewmodel.selectOrigin($0) },
                onRetry: {
                    Task { await viewmodel.loadMailboxes() }
                },
                onClaimMailbox: {
                    pendingClaimBoxNavigation = true
                    viewmodel.isOriginPickerPresented = false
                }
            )
        }
        .navigationDestination(item: $viewmodel.presentedComposer) { page in
            LetterComposerDestination(viewmodel: viewmodel, page: page)
        }
        .onChange(of: viewmodel.presentedComposer) { previous, current in
            guard current == nil, let previous else { return }
            viewmodel.handleComposerDismissed(previous)
        }
        .onChange(of: viewmodel.createdTrackingNumber) { _, trackingNumber in
            guard let trackingNumber else { return }
            router?.replaceStack(
                with: .track(
                    trackingNum: trackingNumber,
                    letter: viewmodel.sentLetterSummary,
                    isRecipient: false
                )
            )
        }
        .alert("Couldn't Send", isPresented: Binding(
            get: { viewmodel.sendErrorMessage != nil },
            set: { if !$0 { viewmodel.sendErrorMessage = nil } }
        )) {
                if viewmodel.needsStamps {
                if viewmodel.canClaimStampAllowance {
                    Button(PromoText.claimFreeStamps) {
                        MonetizationAnalytics.claimTapped(source: .sendAlert)
                        Task { await viewmodel.claimStampAllowance() }
                    }
                }
                Button(PromoText.upgradeToPlus) {
                    viewmodel.sendErrorMessage = nil
                    presentPaywall(source: .sendAlert)
                }
                Button("OK", role: .cancel) {
                    viewmodel.retryStampPhase()
                }
            } else {
                Button("OK", role: .cancel) {
                    viewmodel.retryStampPhase()
                }
            }
        } message: {
            Text(viewmodel.sendErrorMessage ?? "")
        }
        .alert("Couldn't Load Mailboxes", isPresented: Binding(
            get: { viewmodel.shouldPresentMailboxLoadAlert },
            set: { if !$0 { viewmodel.dismissMailboxLoadAlert() } }
        )) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                Task { await viewmodel.loadMailboxes() }
            }
        } message: {
            Text(viewmodel.loadErrorMessage ?? "")
        }
        .sheet(isPresented: $isPaywallPresented) {
            PlusPaywallSheet(source: paywallSource) {
                Task {
                    await viewmodel.refreshEntitlementsAfterPurchase()
                    await viewmodel.refreshLimits()
                    viewmodel.presentSendConfirmation()
                }
            }
        }
        .sheet(isPresented: $viewmodel.isSendConfirmationPresented, onDismiss: {
            viewmodel.handleSendConfirmationDismissed()
        }) {
            SendConfirmationSheet(
                stampCost: viewmodel.currentStampCost,
                stampBalance: viewmodel.entitlements?.unlimitedSends == true
                    ? nil
                    : viewmodel.entitlements?.stampBalance,
                unlimitedSends: viewmodel.entitlements?.unlimitedSends == true,
                scheduling: viewmodel.schedulingEntitlements,
                routeEstimate: viewmodel.routeEstimate,
                isLoadingEstimate: viewmodel.isLoadingRouteEstimate,
                estimateError: viewmodel.routeEstimateError,
                selectedTiming: $viewmodel.selectedSendTiming,
                customDeliverAt: $viewmodel.customDeliverAt,
                onConfirm: {
                    viewmodel.confirmSendFromSheet()
                },
                onUpgrade: viewmodel.entitlements?.unlimitedSends == true
                    ? nil
                    : {
                        viewmodel.isSendConfirmationPresented = false
                        presentPaywall(source: .stampPhase)
                    }
            )
        }
    }

    private func presentPaywall(source: PaywallSource) {
        MonetizationAnalytics.upgradeTapped(source: source)
        paywallSource = source
        isPaywallPresented = true
    }
}

// MARK: - Composer destination

/// Owns observation of draft status so write/draw pages stay live while pushed.
private struct LetterComposerDestination: View {
    @Bindable var viewmodel: LetterCreationView.ViewModel
    let page: LetterComposerPage

    var body: some View {
        switch page {
        case .write:
            LetterTextComposerView(
                initialText: viewmodel.letterText,
                draftSaveStatus: $viewmodel.draftSaveStatus,
                limits: viewmodel.limits,
                onTextChange: { text in
                    viewmodel.updateInProgressText(text)
                },
                onContinue: { text in
                    viewmodel.finishText(text)
                }
            )
        case .draw:
            CanvasView(
                initialDrawingData: viewmodel.drawingData,
                draftSaveStatus: $viewmodel.draftSaveStatus,
                limits: viewmodel.limits,
                onDrawingChange: { data in
                    viewmodel.updateInProgressDrawing(data)
                },
                onContinue: { data in
                    viewmodel.finishDrawing(data)
                }
            )
        }
    }
}

// MARK: - Floating chrome

/// Soft fade behind caption/chrome so controls stay readable while the letter
/// can still read through at the edges (no hard shelf clipping the stage).
private struct FloatingChromeScrim: View {
    enum Edge {
        case top
        case bottom
    }

    let edge: Edge

    var body: some View {
        LinearGradient(
            colors: edge == .top
                ? [Color(.systemGroupedBackground).opacity(0.92), Color(.systemGroupedBackground).opacity(0)]
                : [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground).opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(.all)
        .allowsHitTesting(false)
    }
}

// MARK: - Caption (phase copy only)

private struct LetterCreationCaption: View {
    @Bindable var viewmodel: LetterCreationView.ViewModel
    var onUpgrade: () -> Void

    /// On iOS 26+, title/subtitle live in the nav bar via `navigationSubtitle`.
    private var showsInlinePhaseCopy: Bool {
        if #available(iOS 26.0, *) {
            return false
        }
        return true
    }

    private var hasAccessories: Bool {
        if viewmodel.showsEarlyStampChip && viewmodel.stampChipContent != nil {
            return true
        }
        // Draft status uses toolbar `.subtitle` on iOS 26+.
        if #available(iOS 26.0, *) {
            return false
        }
        return viewmodel.phase == .letterType && viewmodel.draftSaveStatus != .hidden
    }

    var body: some View {
        if showsInlinePhaseCopy || hasAccessories {
            VStack(spacing: 4) {
                if showsInlinePhaseCopy {
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
                }
                if viewmodel.showsEarlyStampChip, let chip = viewmodel.stampChipContent {
                    StampBalanceChip(content: chip, onUpgrade: onUpgrade)
                        .padding(.top, showsInlinePhaseCopy ? 4 : 0)
                }
                if showsInlinePhaseCopy,
                   viewmodel.phase == .letterType,
                   viewmodel.draftSaveStatus != .hidden {
                    DraftSaveStatusLabel(status: viewmodel.draftSaveStatus)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: showsInlinePhaseCopy ? 44 : 0, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background {
                FloatingChromeScrim(edge: .top)
            }
            .animation(LetterCreationMotion.soft, value: viewmodel.phase)
            .animation(LetterCreationMotion.soft, value: viewmodel.stampBalanceLabel)
        }
    }
}

private extension View {
    /// `navigationSubtitle` is iOS 26+; no-op on earlier OS versions.
    @ViewBuilder
    func letterCreationNavigationSubtitle(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) {
            self.navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}

/// Compact stamp balance for compose phases before the stamp step.
private struct StampBalanceChip: View {
    let content: LetterCreationView.ViewModel.StampChipContent
    var onUpgrade: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Label(content.label, systemImage: LetterCreationAsset.envelope.systemName)
                .font(.caption.weight(.medium))
                .foregroundStyle(content.isWarning ? Color.orange : Color.secondary)
                .labelStyle(.titleAndIcon)

            if let detail = content.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if content.showsUpgrade {
                Button(PromoText.plusShort, action: onUpgrade)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemFill))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stage (stable letter + envelope tree)

private struct LetterCreationStage: View {
    @Bindable var viewmodel: LetterCreationView.ViewModel

    private static let stageMaxWidth: CGFloat = 500
    private static let stageHorizontalInset: CGFloat = 32
    /// Small gap inside the caption/chrome well (not a translate-only top offset).
    private static let wellPadding: CGFloat = 8

    var body: some View {
        // Viewport is the visible well between floating caption/chrome.
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
        let usableHeight = max(size.height - Self.wellPadding * 2, 0)
        let envelopeHeight = usableHeight * (revealed ? 0.30 : 0.78)
        let letterHeight = usableHeight * (revealed ? 0.88 : 0.52)
        let letterWidth = size.width - 24

        let envelopeOffsetY: CGFloat = revealed
            ? Self.wellPadding + letterHeight - 28
            : Self.wellPadding + max(0, (usableHeight - envelopeHeight) * 0.04)
        let letterOffsetY: CGFloat = revealed
            ? Self.wellPadding
            : envelopeOffsetY + envelopeHeight * 0.08

        return ZStack(alignment: .top) {
            LetterSheetView(
                content: viewmodel.letterSheetContent,
                isHighlighted: viewmodel.highlightedRegion == .body,
                isInteractive: viewmodel.phase == .letterType && revealed,
                warning: viewmodel.contentWarning,
                onWrite: { viewmodel.selectComposeKind(.text) },
                onDraw: { viewmodel.selectComposeKind(.drawing) },
                onEdit: { viewmodel.editContent() },
                onDiscard: { viewmodel.discardContent() }
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
                isStampInteractive: viewmodel.phase == .stamp && !viewmodel.isSending && !viewmodel.isClaimingAllowance,
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

// MARK: - Chrome

private struct LetterCreationChrome: View {
    @Bindable var viewmodel: LetterCreationView.ViewModel
    var onUpgrade: () -> Void
    var onClaim: () -> Void

    var body: some View {
        switch viewmodel.phase {
        case .letterType, .compose:
            stepNavigationRow(showContinue: viewmodel.hasComposedContent)
        case .stamp:
            VStack(spacing: 10) {
                if viewmodel.needsStampsBeforeSend {
                    if viewmodel.canClaimStampAllowance {
                        Button(action: onClaim) {
                            if viewmodel.isClaimingAllowance {
                                ProgressView()
                            } else {
                                Text(PromoText.claimFreeStamps)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(viewmodel.isClaimingAllowance)

                        Button(PromoText.upgradeToPlus, action: onUpgrade)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    } else {
                        Button(PromoText.upgradeToPlus, action: onUpgrade)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    }
                }

                HStack(spacing: 12) {
                    if viewmodel.canGoBack {
                        Button {
                            viewmodel.enqueueBack()
                        } label: {
                            Label("Back", systemImage: "chevron.backward")
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer(minLength: 0)

                    if !viewmodel.needsStampsBeforeSend {
                        Button {
                            viewmodel.reopenSendConfirmation()
                        } label: {
                            Label(
                                viewmodel.hasConfirmedSendTiming
                                    ? PromoText.sendConfirmationEdit
                                    : PromoText.sendConfirmationReopen,
                                systemImage: "slider.horizontal.3"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            !viewmodel.canSend
                                || viewmodel.isSending
                                || viewmodel.isClaimingAllowance
                                || viewmodel.isSendConfirmationPresented
                        )
                    }
                }
            }
        case .sending:
            ProgressView("Sending…")
                .frame(maxWidth: .infinity)
        case .returnAddress:
            if viewmodel.ownedMailboxes.isEmpty && !viewmodel.isLoadingMailboxes {
                VStack(spacing: 10) {
                    if viewmodel.loadErrorMessage != nil {
                        Button("Retry") {
                            Task { await viewmodel.loadMailboxes() }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    } else {
                        NavigationLink(value: ViewRoute.claimBox) {
                            Text("Claim a Mailbox")
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                    stepNavigationRow(showContinue: false)
                }
            } else {
                stepNavigationRow(showContinue: true)
            }
        case .destination:
            stepNavigationRow(showContinue: true)
        case .overview:
            ProgressView()
                .frame(maxWidth: .infinity)
        default:
            Color.clear
        }
    }

    private func stepNavigationRow(showContinue: Bool) -> some View {
        HStack(spacing: 12) {
            if viewmodel.canGoBack {
                Button {
                    viewmodel.enqueueBack()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .buttonStyle(.bordered)
            }

            Spacer(minLength: 0)

            if showContinue {
                Button {
                    viewmodel.enqueueForward()
                } label: {
                    Label(
                        viewmodel.continueTitle,
                        systemImage: "chevron.forward"
                    )
                    .labelStyle(SwappedLabelStyle())
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewmodel.canAdvance)
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
    var loadErrorMessage: String? = nil
    let onSelect: (MailboxSummary) -> Void
    var onRetry: (() -> Void)? = nil
    let onClaimMailbox: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your mailboxes…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if mailboxes.isEmpty {
                    ContentUnavailableView {
                        Label(
                            loadErrorMessage == nil ? "No Mailboxes" : "Couldn't Load Mailboxes",
                            systemImage: loadErrorMessage == nil ? "tray" : "wifi.slash"
                        )
                    } description: {
                        Text(
                            loadErrorMessage
                                ?? "Claim a mailbox before sending letters."
                        )
                    } actions: {
                        if let onRetry, loadErrorMessage != nil {
                            Button("Try Again", action: onRetry)
                                .buttonStyle(.borderedProminent)
                        }
                        if loadErrorMessage == nil {
                            Button("Claim a Mailbox") {
                                onClaimMailbox()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Claim a Mailbox") {
                                onClaimMailbox()
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
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
                if #available(iOS 26.0, *) {
                    ToolbarItem {
                        Button(role: .cancel, action: { dismiss() })
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
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
        let api: APIClient
        let drafts: DraftLetterStoring
        let entitlementsService: EntitlementsProviding
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
        /// Blocking mailbox-load alert only when the user is on the return-address step.
        var shouldPresentMailboxLoadAlert = false

        var letterText = ""
        /// Cached metrics so chrome doesn't re-scan UTF-8 / trim on every read path unnecessarily.
        private(set) var letterByteCount = 0
        private(set) var letterIsBlank = true

        var composeKind: LetterComposeKind?
        var drawingData: Data?
        var presentedComposer: LetterComposerPage?
        var draftSaveStatus: DraftSaveStatus = .hidden

        var isStampApplied = false
        var isSending = false
        var isClaimingAllowance = false
        var sendErrorMessage: String?
        var needsStamps = false
        var createdTrackingNumber: String?
        /// Snapshot passed into tracking after a successful send.
        var sentLetterSummary: LetterSummary?
        var limits: LetterLimits?

        var isSendConfirmationPresented = false
        var selectedSendTiming: LetterSendTimingOption?
        var customDeliverAt = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        var routeEstimate: ShipmentEstimate?
        var isLoadingRouteEstimate = false
        var routeEstimateError: String?
        /// Set only after the confirmation sheet completes (may be `nil` for natural delivery).
        private var pendingSendSchedule: ShipmentSchedule?
        private(set) var hasConfirmedSendTiming = false

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
            entitlementsService: EntitlementsProviding = AppServices.entitlements,
            origin: MailboxSummary? = nil,
            destination: MailboxSummary? = nil,
            draftID: UUID? = nil
        ) {
            self.api = api
            self.drafts = drafts
            self.entitlementsService = entitlementsService
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
                letterPlacement = phase == .letterType ? .revealed : .tucked
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
            case .compose:
                return .letterType
            case .overview:
                return composeKind == nil ? .destination : .letterType
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
            if !isEmpty || presentedComposer == .draw {
                // Keep draw mode while the canvas is open so an empty clear still autosaves state.
                composeKind = .drawing
            }
            scheduleDebouncedAutosave()
        }

        /// Persist keystrokes while the writing composer is open.
        @MainActor
        func updateInProgressText(_ text: String) {
            letterText = text
            recomputeLetterMetrics(from: text)
            if !letterIsBlank || presentedComposer == .write {
                composeKind = .text
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

        var entitlements: UserEntitlements? {
            entitlementsService.entitlements
        }

        var needsStampsBeforeSend: Bool {
            guard let entitlements else { return false }
            return !entitlements.hasStampsToSend(cost: currentStampCost)
        }

        /// Prefer limits tariff while composing; fall back to entitlements pricing.
        var currentStampCost: Int {
            let kind = composeKind ?? .text
            if let limits {
                return limits.stampCost(byteSize: contentByteCount, kind: kind)
            }
            guard let entitlements else {
                return StampPricing.default.cost(
                    byteSize: contentByteCount,
                    kind: kind,
                    unlimitedSends: false
                )
            }
            return entitlements.stampCost(byteSize: contentByteCount, kind: kind)
        }

        var canClaimStampAllowance: Bool {
            entitlements?.allowance.claimable == true
        }

        /// Prefer limits while composing; fall back to entitlements / free defaults.
        var schedulingEntitlements: SchedulingEntitlements {
            limits?.scheduling
                ?? entitlements?.scheduling
                ?? .freeDefaults
        }

        var stampBalanceLabel: String? {
            guard let entitlements else { return nil }
            if entitlements.unlimitedSends {
                return PromoText.unlimitedSendsWithPlus
            }
            return PromoText.stampBalance(entitlements.stampBalance)
        }

        var nextStampClaimLabel: String? {
            guard let nextClaim = entitlements?.allowance.nextClaimAt, !nextClaim.isEmpty else {
                return nil
            }
            return PromoText.nextFreeStampClaim(at: nextClaim)
        }

        /// Shown from destination through compose so users know balance before the stamp step.
        var showsEarlyStampChip: Bool {
            switch phase {
            case .destination, .returnAddress, .letterType, .compose:
                return stampChipContent != nil
            default:
                return false
            }
        }

        struct StampChipContent: Equatable {
            var label: String
            var detail: String?
            var isWarning: Bool
            var showsUpgrade: Bool
        }

        var stampChipContent: StampChipContent? {
            guard let entitlements else { return nil }
            if entitlements.unlimitedSends {
                return StampChipContent(
                    label: PromoText.unlimitedSends,
                    detail: nil,
                    isWarning: false,
                    showsUpgrade: false
                )
            }

            let balance = PromoText.stampBalance(entitlements.stampBalance)
            let cost = currentStampCost
            let costDetail: String? = cost > 0 ? PromoText.stampCostForLetter(cost) : nil

            if entitlements.hasStampsToSend(cost: cost) {
                return StampChipContent(
                    label: balance,
                    detail: costDetail,
                    isWarning: false,
                    showsUpgrade: false
                )
            }

            if canClaimStampAllowance {
                return StampChipContent(
                    label: PromoText.claimStampsToSend,
                    detail: balance,
                    isWarning: true,
                    showsUpgrade: false
                )
            }

            return StampChipContent(
                label: PromoText.outOfStamps,
                detail: nextStampClaimLabel,
                isWarning: true,
                showsUpgrade: true
            )
        }

        var hasComposedContent: Bool {
            switch composeKind {
            case .text:
                return !letterIsBlank
            case .drawing:
                return !(drawingData?.isEmpty ?? true)
            case nil:
                return false
            }
        }

        var contentByteCount: Int {
            switch composeKind {
            case .text: return letterByteCount
            case .drawing: return drawingData?.count ?? 0
            case nil: return 0
            }
        }

        var isOverContentLimit: Bool {
            guard let composeKind, let limits else { return false }
            return limits.exceedsLimit(contentByteCount, for: composeKind)
        }

        var contentWarning: String? {
            guard let composeKind, let limits, isOverContentLimit else { return nil }
            return limits.overLimitMessage(byteCount: contentByteCount, for: composeKind)
        }

        var letterSheetContent: LetterSheetContent {
            switch composeKind {
            case .text where !letterIsBlank:
                return .text(letterText)
            case .drawing:
                if let drawingData, !drawingData.isEmpty {
                    return .drawing(drawingData)
                }
                return defaultSheetContent
            default:
                return defaultSheetContent
            }
        }

        private var defaultSheetContent: LetterSheetContent {
            phase == .letterType ? .chooser : .blank
        }

        var canSend: Bool {
            guard selectedOriginMailbox != nil,
                  selectedDestinationMailbox != nil,
                  !isSending
            else { return false }

            return hasComposedContent && !isOverContentLimit
        }

        var canAdvance: Bool {
            switch phase {
            case .destination:
                return selectedDestinationMailbox != nil
            case .returnAddress:
                return selectedOriginMailbox != nil
            case .letterType, .compose:
                return hasComposedContent && !isOverContentLimit
            default:
                return false
            }
        }

        var canGoBack: Bool {
            switch phase {
            case .destination:
                return hasComposedContent || composeKind != nil
            case .returnAddress, .stamp:
                return true
            case .letterType, .compose:
                return selectedDestinationMailbox != nil || selectedOriginMailbox != nil
            default:
                return false
            }
        }

        var continueTitle: String {
            switch phase {
            case .letterType, 
                    .compose where !canSend:
                return "Add Addresses"
            default:
                return "Continue"
            }
        }

        var highlightedRegion: LetterCreationRegion? {
            switch phase {
            case .destination: return .destination
            case .returnAddress: return .returnAddress
            case .letterType, .compose: return .body
            case .stamp, .sending: return .stamp
            default: return nil
            }
        }

        var phaseTitle: String {
            switch phase {
            case .overview: return "New Letter"
            case .destination: return "Destination"
            case .returnAddress: return "Return Address"
            case .letterType, .compose: return "Your Letter"
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
            case .letterType, .compose:
                switch composeKind {
                case .text where !letterIsBlank:
                    return selectedDestinationMailbox == nil
                        ? "Saved as a draft. Add addresses when you're ready."
                        : "Tap Edit to keep writing, or continue."
                case .drawing where hasComposedContent:
                    return selectedDestinationMailbox == nil
                        ? "Saved as a draft. Add addresses when you're ready."
                        : "Tap Edit to keep drawing, or continue."
                default:
                    return selectedDestinationMailbox == nil && selectedOriginMailbox == nil
                        ? "Write or draw now. You can pick mailboxes later."
                        : "Write your letter or draw it."
                }
            case .stamp:
                if needsStampsBeforeSend {
                    if canClaimStampAllowance {
                        return PromoText.stampPhaseClaimOrUpgrade
                    }
                    if let nextStampClaimLabel {
                        return "\(PromoText.stampPhaseOutOfStamps) \(nextStampClaimLabel)"
                    }
                    return PromoText.stampPhaseOutOfStamps
                }
                if hasConfirmedSendTiming {
                    return PromoText.stampPhaseTapToSend
                }
                return PromoText.stampPhaseReviewSend
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

        func dismissMailboxLoadAlert() {
            shouldPresentMailboxLoadAlert = false
        }

        func loadMailboxes() async {
            isLoadingMailboxes = true
            loadErrorMessage = nil
            defer { isLoadingMailboxes = false }

            do {
                ownedMailboxes = try await api.listOwnedMailboxes()
                loadErrorMessage = nil
                shouldPresentMailboxLoadAlert = false
                if selectedOriginMailboxID == nil, ownedMailboxes.count == 1 {
                    selectedOriginMailboxID = ownedMailboxes[0].id
                } else if let selectedOriginMailboxID,
                          !ownedMailboxes.contains(where: { $0.id == selectedOriginMailboxID }) {
                    self.selectedOriginMailboxID = nil
                }
            } catch {
                loadErrorMessage = error.postalLoadFailure.message
                // Don't interrupt drafting; only alert if the user is choosing a return address.
                shouldPresentMailboxLoadAlert = phase == .returnAddress
            }
        }

        @MainActor
        func refreshEntitlements() async {
            await entitlementsService.refresh()
        }

        @MainActor
        func refreshEntitlementsAfterPurchase() async {
            await entitlementsService.refreshAfterPurchase()
        }

        @MainActor
        func refreshLimits() async {
            do {
                limits = try await api.getLimits()
            } catch {
                limits = nil
            }
        }

        @MainActor
        func claimStampAllowance() async {
            isClaimingAllowance = true
            sendErrorMessage = nil
            needsStamps = false
            defer { isClaimingAllowance = false }

            do {
                _ = try await entitlementsService.claimStampAllowance()
                if phase == .stamp {
                    presentSendConfirmation()
                }
            } catch {
                sendErrorMessage = error.localizedDescription
            }
        }

        @MainActor
        func beginGuidedFlow() async {
            withAnimation(LetterCreationMotion.envelope) {
                envelopeVisible = true
                letterPlacement = phase == .letterType ? .revealed : .tucked
            }

            if isResumingDraft {
                isResumingDraft = false
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                refreshCamera(animated: true)
                if phase == .stamp {
                    presentSendConfirmation()
                }
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
                // Compose first so drafts work with no network and no mailboxes yet.
                nextPhase = .letterType
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
                if selectedOriginMailbox != nil {
                    await transition(to: .letterType, zoomOutFirst: true)
                } else {
                    await transition(to: .returnAddress, zoomOutFirst: true)
                }
            case .returnAddress:
                guard selectedOriginMailbox != nil else { return }
                if hasComposedContent, !isOverContentLimit, selectedDestinationMailbox != nil {
                    await transition(to: .stamp, zoomOutFirst: true)
                } else {
                    await transition(to: .letterType, zoomOutFirst: true)
                }
            case .letterType, .compose:
                guard hasComposedContent, !isOverContentLimit else { return }
                if canSend {
                    await transition(to: .stamp, zoomOutFirst: true)
                } else if selectedDestinationMailbox == nil {
                    await transition(to: .destination, zoomOutFirst: true)
                } else {
                    await transition(to: .returnAddress, zoomOutFirst: true)
                }
            default:
                break
            }
        }

        @MainActor
        func goBack(dismiss: DismissAction? = nil) async {
            switch phase {
            case .destination:
                if hasComposedContent || composeKind != nil {
                    await transition(to: .letterType, zoomOutFirst: true)
                } else if let dismiss {
                    dismiss()
                }
            case .returnAddress:
                if selectedDestinationMailbox == nil {
                    await transition(to: .letterType, zoomOutFirst: true)
                } else {
                    await transition(to: .destination, zoomOutFirst: true)
                }
            case .letterType, .compose:
                if selectedOriginMailbox == nil, selectedDestinationMailbox == nil {
                    break
                } else if selectedOriginMailbox == nil {
                    await transition(to: .destination, zoomOutFirst: true)
                } else {
                    await transition(to: .returnAddress, zoomOutFirst: true)
                }
            case .stamp:
                isStampApplied = false
                await transition(to: .letterType, zoomOutFirst: true)
            default:
                break
            }
        }

        /// Picks a compose style from the letter and pushes the matching composer page.
        @MainActor
        func selectComposeKind(_ kind: LetterComposeKind) {
            composeKind = kind
            switch kind {
            case .text:
                drawingData = nil
            case .drawing:
                letterText = ""
                recomputeLetterMetrics(from: "")
            }
            scheduleAutosave()
            presentedComposer = LetterComposerPage(kind)
        }

        /// Reopens the composer that owns the current content.
        @MainActor
        func editContent() {
            guard let composeKind else { return }
            presentedComposer = LetterComposerPage(composeKind)
        }

        /// Clears the letter so the write/draw options come back.
        @MainActor
        func discardContent() {
            composeKind = nil
            letterText = ""
            recomputeLetterMetrics(from: "")
            drawingData = nil
            scheduleAutosave()
        }

        @MainActor
        func finishText(_ text: String) {
            letterText = text
            recomputeLetterMetrics(from: text)
            composeKind = .text
            drawingData = nil
            finishComposing()
        }

        @MainActor
        func finishDrawing(_ data: Data) {
            drawingData = data.isEmpty ? nil : data
            composeKind = .drawing
            letterText = ""
            recomputeLetterMetrics(from: "")
            finishComposing()
        }

        /// Pops the composer. Only jumps to send when both mailboxes are already chosen.
        @MainActor
        private func finishComposing() {
            guard hasComposedContent, !isOverContentLimit else { return }
            presentedComposer = nil
            scheduleAutosave()

            // Stay on the letter so offline drafts don't dump the user into a network picker.
            if selectedDestinationMailbox != nil, selectedOriginMailbox != nil {
                transitionTask?.cancel()
                transitionTask = Task { @MainActor in
                    await transition(to: .stamp, zoomOutFirst: false)
                }
            }
        }

        /// Popped without continuing — fall back to the options unless content was saved.
        @MainActor
        func handleComposerDismissed(_ page: LetterComposerPage) {
            guard !hasComposedContent,
                  let kind = composeKind,
                  LetterComposerPage(kind) == page
            else { return }
            composeKind = nil
            scheduleAutosave()
        }

        @MainActor
        func presentSendConfirmation() {
            guard phase == .stamp, canSend, !isStampApplied, !isSending else { return }
            guard !needsStampsBeforeSend else { return }
            guard !isSendConfirmationPresented else { return }

            selectedSendTiming = nil
            pendingSendSchedule = nil
            hasConfirmedSendTiming = false
            routeEstimate = nil
            routeEstimateError = nil
            isSendConfirmationPresented = true
            Task { await loadRouteEstimateIfNeeded() }
        }

        /// Re-open the sheet without wiping a prior choice (edit / change of mind).
        @MainActor
        func reopenSendConfirmation() {
            guard phase == .stamp, canSend, !isStampApplied, !isSending else { return }
            guard !needsStampsBeforeSend else { return }
            guard !isSendConfirmationPresented else { return }

            routeEstimateError = nil
            isSendConfirmationPresented = true
            Task { await loadRouteEstimateIfNeeded() }
        }

        @MainActor
        func confirmSendFromSheet() {
            guard let selectedSendTiming else { return }

            let schedule: ShipmentSchedule?
            switch selectedSendTiming {
            case .natural:
                schedule = nil
            case let .preset(preset):
                schedule = .preset(preset)
            case .custom:
                guard schedulingEntitlements.customDeliverAt else { return }
                let minimum = max(routeEstimate?.expectedDeliveryTime ?? .now, .now)
                guard customDeliverAt >= minimum else {
                    routeEstimateError = PromoText.sendTimingHoldTooEarly
                    return
                }
                schedule = .deliverAt(customDeliverAt)
            }

            pendingSendSchedule = schedule
            hasConfirmedSendTiming = true
            isSendConfirmationPresented = false
        }

        func handleSendConfirmationDismissed() {
            if hasConfirmedSendTiming {
                // Cancel after editing — restore the last confirmed choice.
                selectedSendTiming = timingOption(matching: pendingSendSchedule)
                return
            }
            selectedSendTiming = nil
            pendingSendSchedule = nil
        }

        private func timingOption(matching schedule: ShipmentSchedule?) -> LetterSendTimingOption {
            switch schedule {
            case nil: .natural
            case let .preset(preset): .preset(preset)
            case .deliverAt: .custom
            }
        }

        @MainActor
        private func loadRouteEstimateIfNeeded() async {
            // Needed for Plus custom-date clamping (and ETA footer).
            guard schedulingEntitlements.routeEstimate || schedulingEntitlements.customDeliverAt,
                  let origin = selectedOriginMailbox,
                  let destination = selectedDestinationMailbox
            else { return }

            isLoadingRouteEstimate = true
            routeEstimateError = nil
            defer { isLoadingRouteEstimate = false }

            do {
                routeEstimate = try await api.estimateShipment(
                    originBoxID: origin.id,
                    destinationBoxID: destination.id
                )
                if let eta = routeEstimate?.expectedDeliveryTime {
                    customDeliverAt = max(customDeliverAt, eta, .now)
                }
            } catch {
                routeEstimate = nil
            }
        }

        @MainActor
        func applyStampAndSend() async {
            guard phase == .stamp, canSend, !isStampApplied, !isSending else { return }

            if needsStampsBeforeSend {
                MonetizationAnalytics.sendBlockedNoStamps()
                needsStamps = true
                sendErrorMessage = canClaimStampAllowance
                    ? PromoText.notEnoughStampsClaimOrUpgrade
                    : PromoText.notEnoughStamps
                return
            }

            guard hasConfirmedSendTiming else {
                presentSendConfirmation()
                return
            }

            isStampApplied = true
            isSending = true
            needsStamps = false

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
            needsStamps = false
            hasConfirmedSendTiming = false
            pendingSendSchedule = nil
            selectedSendTiming = nil
            withAnimation(LetterCreationMotion.soft) {
                envelopeVisible = true
                letterPlacement = .tucked
                camera = .identity
            }
            presentSendConfirmation()
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
                case .letterType, .compose:
                    letterPlacement = .revealed
                case .stamp, .sending, .destination, .returnAddress, .overview:
                    letterPlacement = .tucked
                case .sent:
                    break
                }
            }

            // Wait for letter/envelope layout to settle before measuring & framing.
            try? await Task.sleep(for: .milliseconds(newPhase == .letterType ? 380 : 160))
            guard !Task.isCancelled else { return }
            refreshCamera(animated: true)

            if newPhase == .stamp {
                presentSendConfirmation()
            }
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
                let schedule = pendingSendSchedule
                switch composeKind {
                case .text:
                    let request = CreateShipmentRequest(
                        origin: origin,
                        destination: destination,
                        letter: .plain(letterText.trimmingCharacters(in: .whitespacesAndNewlines)),
                        schedule: schedule
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
                        letter: .pkDrawing(drawingData),
                        schedule: schedule
                    )
                    response = try await api.createShipmentMultipart(request)
                case nil:
                    isStampApplied = false
                    phase = .stamp
                    return
                }

                createdTrackingNumber = response.trackingNumber
                sentLetterSummary = letterSummary(
                    for: response,
                    origin: origin,
                    destination: destination
                )
                deleteDraft()
                if let service = entitlementsService as? EntitlementsService {
                    service.applyLocalStampSpend(spent: currentStampCost)
                }
                await entitlementsService.refresh()
                phase = .sent
            } catch {
                if let apiError = error as? APIError,
                   case let .httpStatus(code, message, _) = apiError,
                   code == 402 {
                    needsStamps = true
                    if let detail = apiError.insufficientStampsDetail {
                        if let required = detail.required, let balance = detail.stampBalance {
                            sendErrorMessage = "\(detail.message ?? PromoText.notEnoughStamps) Need \(required), have \(balance)."
                        } else {
                            sendErrorMessage = detail.message ?? message ?? PromoText.notEnoughStamps
                        }
                    } else {
                        sendErrorMessage = message ?? PromoText.notEnoughStamps
                    }
                    if let service = entitlementsService as? EntitlementsService {
                        service.invalidateStampBalanceCache()
                    }
                    await entitlementsService.refresh()
                } else {
                    needsStamps = false
                    sendErrorMessage = error.localizedDescription
                }
                isStampApplied = false
                phase = .stamp
                hasConfirmedSendTiming = false
                pendingSendSchedule = nil
                selectedSendTiming = nil
                withAnimation(LetterCreationMotion.soft) {
                    envelopeVisible = true
                    letterPlacement = .tucked
                }
                presentSendConfirmation()
            }
        }

        private func letterSummary(
            for response: ShipmentCreateResponse,
            origin: MailboxSummary,
            destination: MailboxSummary
        ) -> LetterSummary {
            LetterSummary(
                trackingNumber: response.trackingNumber,
                shipmentID: response.id,
                origin: LetterEndpoint(mailboxID: origin.id),
                destination: LetterEndpoint(mailboxID: destination.id),
                status: response.status,
                hasLetter: response.letter != nil,
                letterFormat: response.letter?.format,
                letterMimeType: response.letter?.mimeType,
                letterEncoding: response.letter?.encoding,
                letterByteSize: response.letter?.byteSize,
                canReadLetter: false,
                expectedDeliveryTime: response.expectedDeliveryTime,
                scheduledDeliveryAt: response.scheduledDeliveryAt,
                createdAt: .now,
                updatedAt: .now
            )
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
            case .overview, .sent:
                return .identity
            case .destination:
                region = .destination
                padding = 1.55
            case .returnAddress:
                region = .returnAddress
                padding = 1.7
            case .letterType, .compose:
                // Letter already fills the stage — zooming crops the options/preview.
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

            // Stage is top-centered in the visible well between floating chrome;
            // camera transforms share that coordinate space.
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

#Preview("Write or Draw") {
    NavigationStack {
        LetterCreationView(viewmodel: .preview(
            phase: .letterType,
            selectedOriginMailbox: PreviewData.ownedMailboxes[0],
            selectedDestinationMailbox: PreviewData.destinationMailboxes[1]
        ), loadsOnAppear: false)
    }
    .environment(Router())
}

#Preview("Written Letter") {
    NavigationStack {
        LetterCreationView(viewmodel: .preview(
            phase: .letterType,
            selectedOriginMailbox: PreviewData.ownedMailboxes[0],
            selectedDestinationMailbox: PreviewData.destinationMailboxes[1],
            letterText: PreviewData.sampleLetterText,
            composeKind: .text
        ), loadsOnAppear: false)
    }
    .environment(Router())
}

#Preview("Over Size Limit") {
    NavigationStack {
        LetterCreationView(viewmodel: .preview(
            phase: .letterType,
            selectedOriginMailbox: PreviewData.ownedMailboxes[0],
            selectedDestinationMailbox: PreviewData.destinationMailboxes[1],
            letterText: String(repeating: "A", count: LetterLimits.preview.maxTextBytes + 1),
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

#Preview("Draft Without Mailboxes") {
    NavigationStack {
        LetterCreationView(viewmodel: .preview(
            phase: .letterType,
            ownedMailboxes: [],
            letterText: PreviewData.sampleLetterText,
            composeKind: .text
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
