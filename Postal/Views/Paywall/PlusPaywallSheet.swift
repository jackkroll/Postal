import RevenueCat
import RevenueCatUI
import SwiftUI

/// Presents RevenueCat’s remote paywall for the Plus entitlement.
struct PlusPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onPurchaseCompleted: (() -> Void)?

    var body: some View {
        PaywallView()
            .onPurchaseCompleted { _ in
                onPurchaseCompleted?()
                dismiss()
            }
            .onRestoreCompleted { _ in
                onPurchaseCompleted?()
                dismiss()
            }
    }
}
