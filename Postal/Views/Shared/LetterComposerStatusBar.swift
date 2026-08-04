import SwiftUI

/// Top chrome shared by write and draw composer pages: one inline usage meter (+ draft on older OS).
struct LetterComposerStatusBar: View {
    @Binding var draftSaveStatus: DraftSaveStatus
    let byteCount: Int
    let kind: LetterComposeKind
    let limits: LetterLimits

    private var isOverLimit: Bool {
        limits.exceedsLimit(byteCount, for: kind)
    }

    private var stampCost: Int {
        limits.stampCost(byteSize: byteCount, kind: kind)
    }

    private var meterFraction: Double {
        limits.meterFraction(byteCount: byteCount, for: kind)
    }

    /// Draft status uses toolbar `.subtitle` on iOS 26+.
    private var showsInlineDraftStatus: Bool {
        if #available(iOS 26.0, *) {
            return false
        }
        return true
    }

    private var inlineLabel: String? {
        if isOverLimit {
            return limits.overAmountDescription(byteCount: byteCount, for: kind)
        }
        if limits.usesStampMeter {
            return stampCost > 1
                ? PromoText.usingStampCount(stampCost)
                : PromoText.stampCount(max(stampCost, 1))
        }
        guard meterFraction >= 0.8 else { return nil }
        return limits.formattedUsage(byteCount: byteCount, for: kind)
    }

    var body: some View {
        HStack(spacing: 8) {
            if showsInlineDraftStatus {
                DraftSaveStatusLabel(status: draftSaveStatus)
            }
            Spacer(minLength: 0)
            if isOverLimit {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.red)
                    .accessibilityHidden(true)
            }
            if let inlineLabel {
                Text(inlineLabel)
                    .font(.caption2)
                    .foregroundStyle(isOverLimit ? Color.red : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            LetterLimitsProgressBar(byteCount: byteCount, kind: kind, limits: limits)
                .frame(maxWidth: 140)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .animation(.snappy(duration: 0.2), value: isOverLimit)
        .animation(.snappy(duration: 0.2), value: stampCost)
        .animation(.snappy(duration: 0.2), value: byteCount)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Free first stamp") {
    LetterComposerStatusBar(
        draftSaveStatus: .constant(.saving),
        byteCount: 1_024,
        kind: .text,
        limits: .preview
    )
}

#Preview("Free second stamp") {
    LetterComposerStatusBar(
        draftSaveStatus: .constant(.saved),
        byteCount: 5_200,
        kind: .text,
        limits: .previewMultiStamp
    )
}

#Preview("Plus nearing limit") {
    LetterComposerStatusBar(
        draftSaveStatus: .constant(.saved),
        byteCount: 10_500,
        kind: .text,
        limits: .previewPlus
    )
}

#Preview("Over Limit") {
    LetterComposerStatusBar(
        draftSaveStatus: .constant(.saved),
        byteCount: LetterLimits.preview.maxTextBytes + 1,
        kind: .text,
        limits: .preview
    )
}
