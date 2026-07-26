import SwiftUI

/// Top chrome shared by write and draw composer pages: draft chip + byte usage.
struct LetterComposerStatusBar: View {
    @Binding var draftSaveStatus: DraftSaveStatus
    let byteCount: Int
    let kind: LetterComposeKind
    let limits: LetterLimits

    private var isOverLimit: Bool {
        limits.exceedsLimit(byteCount, for: kind)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                DraftSaveStatusLabel(status: draftSaveStatus)
                Spacer(minLength: 0)
                Text(limits.usageLabel(byteCount, for: kind))
                    .font(.caption)
                    .foregroundStyle(isOverLimit ? Color.red : .secondary)
                    .monospacedDigit()
            }

            if isOverLimit {
                Label(limits.overLimitMessage(for: kind), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .animation(.snappy(duration: 0.2), value: draftSaveStatus)
        .animation(.snappy(duration: 0.2), value: isOverLimit)
    }
}

#Preview("Saving") {
    LetterComposerStatusBar(
        draftSaveStatus: .constant(.saving),
        byteCount: 1_024,
        kind: .text,
        limits: AppConfiguration.letterLimits
    )
}

#Preview("Over Limit") {
    LetterComposerStatusBar(
        draftSaveStatus: .constant(.saved),
        byteCount: AppConfiguration.letterLimits.maxTextBytes + 1,
        kind: .text,
        limits: AppConfiguration.letterLimits
    )
}
