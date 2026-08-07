import SwiftUI

struct OnboardingClaimMailboxStep: View {
    @Bindable var store: OnboardingStore
    private let claimViewModel: ClaimMailboxView.ViewModel
    private let loadsOnAppear: Bool

    init(
        store: OnboardingStore,
        claimViewModel: ClaimMailboxView.ViewModel = ClaimMailboxView.ViewModel(api: AppServices.api),
        loadsOnAppear: Bool = true
    ) {
        self.store = store
        self.claimViewModel = claimViewModel
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        VStack {
            OnboardingStepHeader(
                title: PromoText.onboardingClaimTitle,
                bodyText: PromoText.onboardingClaimBody
            )
            ClaimMailboxView(
                viewmodel: claimViewModel,
                loadsOnAppear: loadsOnAppear,
                footerOverride: PromoText.onboardingClaimFooter,
                onClaimed: { mailbox in
                    store.recordClaimedMailbox(mailbox)
                }
            )
        }
        .navigationBarTitleDisplayMode(.large)
        .toolbar{
            if #available(iOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
        }
    }
}

#Preview("Post offices") {
    NavigationStack {
        OnboardingClaimMailboxStep(
            store: .preview(step: .claimMailbox, origin: nil),
            claimViewModel: .preview(),
            loadsOnAppear: false
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                OnboardingSkipMenu(onSkip: {})
            }
        }
    }
}

#Preview("Confirm claim") {
    NavigationStack {
        OnboardingClaimMailboxStep(
            store: .preview(step: .claimMailbox, origin: nil),
            claimViewModel: .preview(
                selectedPostOffice: PreviewData.mainStreetPostOffice
            ),
            loadsOnAppear: false
        )
    }
}
