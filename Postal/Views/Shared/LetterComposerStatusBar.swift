import SwiftUI

/// Top chrome shared by write and draw composer pages: usage meter (+ draft on older OS).
struct LetterComposerStatusBar: View {
    @Binding var draftSaveStatus: DraftSaveStatus
    let byteCount: Int
    let kind: LetterComposeKind
    let limits: LetterLimits

    private var isOverLimit: Bool {
        limits.exceedsLimit(byteCount, for: kind)
    }

    private var fraction: Double {
        limits.usageFraction(byteCount, for: kind)
    }

    /// Draft status uses toolbar `.subtitle` on iOS 26+.
    private var showsInlineDraftStatus: Bool {
        if #available(iOS 26.0, *) {
            return false
        }
        return true
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                if showsInlineDraftStatus {
                    DraftSaveStatusLabel(status: draftSaveStatus)
                }
                Spacer(minLength: 0)
                LetterLimitsProgressBar(byteCount: byteCount, kind: kind, limits: limits)
            }
            HStack(alignment: .center) {
                if isOverLimit {
                    Label(
                        limits.overLimitMessage(byteCount: byteCount, for: kind),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.red)
                } else if fraction >= 0.8 {
                    Text(limits.formattedUsage(byteCount: byteCount, for: kind))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .animation(.snappy(duration: 0.2), value: isOverLimit)
        .animation(.snappy(duration: 0.2), value: byteCount)
    }
}

#Preview("Saving") {
    LetterComposerStatusBar(
        draftSaveStatus: .constant(.saving),
        byteCount: 1_024,
        kind: .text,
        limits: .preview
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
