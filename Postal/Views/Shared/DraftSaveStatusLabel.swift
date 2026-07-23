import SwiftUI

enum DraftSaveStatus: Equatable {
    case hidden
    case saving
    case saved
}

/// Compact status chip so write/draw composers can show draft persistence confidence.
struct DraftSaveStatusLabel: View {
    let status: DraftSaveStatus

    var body: some View {
        switch status {
        case .hidden:
            EmptyView()
        case .saving:
            Label("Saving draft…", systemImage: "ellipsis.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.medium))
                .accessibilityLabel("Saving draft")
                .padding(10)
                .background(.blue.opacity(0.25) )
                .clipShape(.capsule)
        case .saved:
            Label("Draft saved", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.medium))
                .accessibilityLabel("Draft saved")
                .padding(10)
                .background(.green.opacity(0.25) )
                .clipShape(.capsule)
        }
    }
}
#Preview("Saved"){
    DraftSaveStatusLabel(status: .saved)
}

#Preview("Saving") {
    DraftSaveStatusLabel(status: .saving)
}
