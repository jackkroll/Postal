import SwiftUI

struct OnboardingStepHeader: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.weight(.bold))
            Text(bodyText)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

/// Pinned bottom chrome for onboarding continue / primary actions.
struct OnboardingBottomActions<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.bar)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// Toolbar control: a symbol that morphs into a menu to confirm skipping onboarding.
struct OnboardingSkipMenu: View {
    let onSkip: () -> Void

    var body: some View {
        Menu {
            Button(role: .destructive, action: onSkip) {
                Label(PromoText.onboardingSkipConfirm, systemImage: "arrow.right.to.line")
            }
            Button(role: .cancel, action: {}) {
                Label(PromoText.onboardingSkipCancel, systemImage: "xmark")
            }
        } label: {
            Image(systemName: "xmark")
        }
        .accessibilityLabel(PromoText.onboardingSkip)
        .accessibilityHint(PromoText.onboardingSkipConfirm)
    }
}

#Preview("Claim copy") {
    OnboardingStepHeader(
        title: PromoText.onboardingClaimTitle,
        bodyText: PromoText.onboardingClaimBody
    )
}

#Preview("Letter copy") {
    OnboardingStepHeader(
        title: PromoText.onboardingLetterTitle,
        bodyText: PromoText.onboardingLetterBody
    )
}

#Preview("Paywall copy") {
    OnboardingStepHeader(
        title: PromoText.onboardingPaywallTitle,
        bodyText: PromoText.onboardingPaywallBody
    )
}

#Preview("Skip menu") {
    NavigationStack {
        Color.clear
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    OnboardingSkipMenu(onSkip: {})
                }
            }
    }
}
