import RevenueCat
import RevenueCatUI
import SwiftUI

/// Presents RevenueCat’s remote paywall for the Plus entitlement.
struct PlusPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: PaywallSource
    var onPurchaseCompleted: (() -> Void)?

    @State private var didCompletePurchase = false

    var body: some View {
        PaywallView()
            .onAppear {
                MonetizationAnalytics.paywallPresented(source: source)
            }
            .onDisappear {
                if !didCompletePurchase {
                    MonetizationAnalytics.paywallDismissedWithoutPurchase(source: source)
                }
            }
            .onPurchaseCompleted { _ in
                didCompletePurchase = true
                onPurchaseCompleted?()
                dismiss()
            }
            .onRestoreCompleted { _ in
                didCompletePurchase = true
                onPurchaseCompleted?()
                dismiss()
            }
    }
}
