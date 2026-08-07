import SwiftUI

/// Full-screen guided onboarding for new users. Resumes at the persisted step.
struct OnboardingFlowView: View {
    @Bindable var store: OnboardingStore
    var api: APIClient = AppServices.api
    var entitlements: EntitlementsProviding = AppServices.entitlements
    var pendingCapsules: PendingTimeCapsuleStoring = AppServices.pendingTimeCapsules
    /// When false, skips the ownership re-check (previews).
    private let loadsOnAppear: Bool

    init(
        store: OnboardingStore,
        api: APIClient = AppServices.api,
        entitlements: EntitlementsProviding = AppServices.entitlements,
        pendingCapsules: PendingTimeCapsuleStoring = AppServices.pendingTimeCapsules,
        loadsOnAppear: Bool = true
    ) {
        self.store = store
        self.api = api
        self.entitlements = entitlements
        self.pendingCapsules = pendingCapsules
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        NavigationStack {
            Group {
                if let progress = store.progress {
                    stepView(for: progress.step)
                } else {
                    ProgressView("Getting ready…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    OnboardingSkipMenu {
                        store.skipRemaining()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .task {
            guard loadsOnAppear else { return }
            // Re-check ownership in case claim happened elsewhere before this cover appeared.x
            if let mailboxes = try? await api.listOwnedMailboxes() {
                store.skipClaimIfNeeded(ownedMailboxes: mailboxes)
            }
        }
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .claimMailbox:
            OnboardingClaimMailboxStep(store: store, loadsOnAppear: loadsOnAppear)
        case .askDestination:
            OnboardingDestinationStep(store: store, api: api)
        case .composeLetter:
            OnboardingLetterStep(
                store: store,
                api: api,
                pendingCapsules: pendingCapsules,
                loadsOnAppear: loadsOnAppear
            )
        case .claimStamps:
            OnboardingStampsStep(
                store: store,
                entitlements: entitlements,
                loadsOnAppear: loadsOnAppear
            )
        case .paywall:
            OnboardingPaywallStep(
                store: store,
                presentsPaywallOnAppear: loadsOnAppear
            )
        }
    }
}

#Preview("Claim") {
    OnboardingFlowView(
        store: .preview(step: .claimMailbox, origin: nil),
        loadsOnAppear: false
    )
}

#Preview("Destination") {
    OnboardingFlowView(
        store: .preview(step: .askDestination),
        loadsOnAppear: false
    )
}

#Preview("Letter") {
    OnboardingFlowView(
        store: .preview(
            step: .composeLetter,
            savedDestination: PreviewData.destinationMailboxes[0],
            savedDestinationNickname: "Alex"
        ),
        loadsOnAppear: false
    )
}

#Preview("Stamps") {
    OnboardingFlowView(
        store: .preview(step: .claimStamps),
        entitlements: {
            let service = PreviewEntitlementsService()
            service.entitlements = .previewFree
            return service
        }(),
        loadsOnAppear: false
    )
}

#Preview("Paywall") {
    OnboardingFlowView(
        store: .preview(step: .paywall),
        loadsOnAppear: false
    )
}
