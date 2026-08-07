import SwiftUI

struct OnboardingPaywallStep: View {
    @Bindable var store: OnboardingStore
    private let presentsPaywallOnAppear: Bool

    @State private var showPaywall: Bool
    @State private var didFinish = false

    init(
        store: OnboardingStore,
        presentsPaywallOnAppear: Bool = true
    ) {
        self.store = store
        self.presentsPaywallOnAppear = presentsPaywallOnAppear
        _showPaywall = State(initialValue: presentsPaywallOnAppear)
    }

    var body: some View {
        ScrollView {
            OnboardingStepHeader(
                title: PromoText.onboardingPaywallTitle,
                bodyText: PromoText.onboardingPaywallBody
            )
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingBottomActions {
                Button {
                    showPaywall = true
                } label: {
                    Text(PromoText.upgradeToPlus)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Maybe later") {
                    finish()
                }
                .font(.body.weight(.medium))
            }
        }
        .navigationTitle("Plus")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard presentsPaywallOnAppear else { return }
            if AppServices.entitlements.entitlements?.isSubscriber == true {
                finish()
            }
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // Only complete on dismiss when this is a live onboarding presentation.
            guard presentsPaywallOnAppear else { return }
            finish()
        }) {
            PlusPaywallSheet(source: .onboarding) {
                Task {
                    await AppServices.entitlements.refreshAfterPurchase()
                    finish()
                }
            }
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        store.complete()
    }
}

#Preview("Upsell") {
    NavigationStack {
        OnboardingPaywallStep(
            store: .preview(step: .paywall),
            presentsPaywallOnAppear: false
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                OnboardingSkipMenu(onSkip: {})
            }
        }
    }
}
