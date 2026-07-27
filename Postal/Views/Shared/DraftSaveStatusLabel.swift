import SwiftUI

enum DraftSaveStatus: Equatable {
    case hidden
    case saving
    case saved

    var accessibilityLabel: String {
        switch self {
        case .hidden: return ""
        case .saving: return "Saving draft"
        case .saved: return "Draft saved"
        }
    }
}

/// Quiet draft persistence notice for composers and letter creation chrome.
struct DraftSaveStatusLabel: View {
    let status: DraftSaveStatus

    var body: some View {
        Group {
            switch status {
            case .hidden:
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            case .saving:
                label("Saving", systemImage: "arrow.down.document.fill")
            case .saved:
                label("Saved", systemImage: "checkmark")
            }
        }
        .accessibilityLabel(status.accessibilityLabel)
        // Force toolbar subtitle content to refresh when status flips.
        .id(status)
    }

    private func label(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview("Saved") {
    DraftSaveStatusLabel(status: .saved)
}

#Preview("Saving") {
    DraftSaveStatusLabel(status: .saving)
}
