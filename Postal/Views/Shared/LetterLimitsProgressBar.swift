import SwiftUI

/// Compact usage meter: stamp-bucket fill for Free, size ceiling for Plus.
struct LetterLimitsProgressBar: View {
    let byteCount: Int
    let kind: LetterComposeKind
    let limits: LetterLimits

    private var fraction: Double {
        limits.meterFraction(byteCount: byteCount, for: kind)
    }

    private var isOverLimit: Bool {
        limits.exceedsLimit(byteCount, for: kind)
    }

    private var clampedFraction: Double {
        min(max(fraction, 0), 1)
    }

    private var accessibilityName: String {
        limits.usesStampMeter ? "Stamp usage" : "Letter size"
    }

    private var accessibilityDetail: String {
        if isOverLimit {
            return limits.overAmountDescription(byteCount: byteCount, for: kind)
        }
        if limits.usesStampMeter {
            return limits.formattedStampFill(byteCount: byteCount, for: kind)
        }
        return limits.formattedUsage(byteCount: byteCount, for: kind)
    }

    var body: some View {
        ProgressView(value: clampedFraction)
            .tint(isOverLimit ? Color.red : Color.accentColor)
            .accessibilityLabel(accessibilityName)
            .accessibilityValue(accessibilityDetail)
            .animation(.snappy(duration: 0.2), value: limits.stampCost(byteSize: byteCount, kind: kind))
    }
}

#Preview("Free stamp fill") {
    LetterLimitsProgressBar(
        byteCount: 2_400,
        kind: .text,
        limits: .preview
    )
    .padding()
}

#Preview("Free second stamp") {
    LetterLimitsProgressBar(
        byteCount: 4_100,
        kind: .text,
        limits: .previewMultiStamp
    )
    .padding()
}

#Preview("Plus size") {
    LetterLimitsProgressBar(
        byteCount: 8_000,
        kind: .text,
        limits: .previewPlus
    )
    .padding()
}
