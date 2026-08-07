import SwiftUI

struct OnboardingStampsStep: View {
    @Bindable var store: OnboardingStore
    let entitlements: EntitlementsProviding
    private let loadsOnAppear: Bool

    @State private var isClaiming = false
    @State private var claimError: String?
    @State private var didClaim = false

    private var current: UserEntitlements? { entitlements.entitlements }
    private var canClaim: Bool { current?.allowance.claimable == true }

    init(
        store: OnboardingStore,
        entitlements: EntitlementsProviding = AppServices.entitlements,
        loadsOnAppear: Bool = true
    ) {
        self.store = store
        self.entitlements = entitlements
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OnboardingStepHeader(
                    title: PromoText.onboardingStampsTitle,
                    bodyText: PromoText.onboardingStampsBody
                )

                if let current {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Balance", value: PromoText.stampBalance(current.stampBalance))
                        if current.allowance.claimable {
                            Text(PromoText.claimFreeStamps(amount: current.allowance.amount))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if let next = current.allowance.nextClaimAt {
                            Text(PromoText.nextFreeStampClaim(at: next))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if didClaim || !canClaim {
                            Text(PromoText.onboardingStampsAlreadyClaimed)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                if let claimError {
                    Text(claimError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingBottomActions {
                if canClaim {
                    Button {
                        MonetizationAnalytics.claimTapped(source: .onboarding)
                        Task { await claim() }
                    } label: {
                        if isClaiming {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(PromoText.claimFreeStamps(amount: current?.allowance.amount ?? 0))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isClaiming)

                    Button {
                        store.recordStampsStepFinished()
                    } label: {
                        Text(PromoText.onboardingStampsContinue)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button {
                        store.recordStampsStepFinished()
                    } label: {
                        Text(PromoText.onboardingStampsContinue)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .navigationTitle("Stamps")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loadsOnAppear else { return }
            await entitlements.refresh()
        }
    }

    @MainActor
    private func claim() async {
        isClaiming = true
        claimError = nil
        defer { isClaiming = false }
        do {
            _ = try await entitlements.claimStampAllowance()
            didClaim = true
        } catch {
            guard !error.isPostalCancellation else { return }
            claimError = error.postalLoadFailure.message
        }
    }
}

#Preview("Claimable") {
    NavigationStack {
        OnboardingStampsStep(
            store: .preview(step: .claimStamps),
            entitlements: {
                let service = PreviewEntitlementsService()
                service.entitlements = .previewFree
                return service
            }(),
            loadsOnAppear: false
        )
    }
}

#Preview("Already claimed") {
    NavigationStack {
        OnboardingStampsStep(
            store: .preview(step: .claimStamps),
            entitlements: {
                let service = PreviewEntitlementsService()
                service.entitlements = .previewFreeAllowanceClaimed
                return service
            }(),
            loadsOnAppear: false
        )
    }
}
