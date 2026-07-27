import SwiftUI

/// Compact usage meter for letter size ceilings.
struct LetterLimitsProgressBar: View {
    let byteCount: Int
    let kind: LetterComposeKind
    let limits: LetterLimits

    private var fraction: Double {
        limits.usageFraction(byteCount, for: kind)
    }

    private var isOverLimit: Bool {
        limits.exceedsLimit(byteCount, for: kind)
    }

    private var clampedFraction: Double {
        min(max(fraction, 0), 1)
    }

    var body: some View {
        ProgressView(value: clampedFraction)
            .tint(isOverLimit ? Color.red : Color.accentColor)
            .accessibilityLabel("Letter size")
            .accessibilityValue(
                isOverLimit
                    ? limits.overAmountDescription(byteCount: byteCount, for: kind)
                    : limits.formattedUsage(byteCount: byteCount, for: kind)
            )
    }
}

#Preview("Partial") {
    LetterLimitsProgressBar(
        byteCount: 24_000,
        kind: .text,
        limits: AppConfiguration.letterLimits
    )
    .padding()
}

#Preview("Over Limit") {
    LetterLimitsProgressBar(
        byteCount: AppConfiguration.letterLimits.maxTextBytes + 1,
        kind: .text,
        limits: AppConfiguration.letterLimits
    )
    .padding()
}
