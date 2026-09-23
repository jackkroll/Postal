import SwiftUI

/// The capsule marking a row as blocked or reported. An address can carry both,
/// since the two are independent.
struct ModerationBadge: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

#Preview {
    HStack {
        ModerationBadge(BlockText.badge)
        ModerationBadge(ReportText.badge)
    }
}
