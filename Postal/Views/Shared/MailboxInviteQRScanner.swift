import AVFoundation
import CodeScanner
import SwiftUI

/// Full-bleed QR scanner powered by [CodeScanner](https://github.com/twostraws/CodeScanner).
struct MailboxInviteQRScannerPanel: View {
    var simulatedData: String = "https://postal.jackk.dev/invite/1:DEMO"
    var onCode: (String) -> Void
    var onFailure: ((String) -> Void)? = nil

    var body: some View {
        CodeScannerView(
            codeTypes: [.qr],
            scanMode: .once,
            showViewfinder: true,
            simulatedData: simulatedData,
            shouldVibrateOnSuccess: true
        ) { response in
            switch response {
            case let .success(result):
                onCode(result.string)
            case let .failure(error):
                onFailure?(error.localizedDescription)
            }
        }
    }
}

/// Medium sheet for scanning a mailbox invite. Cancel-only chrome; no back button.
struct MailboxInviteQRScannerSheet: View {
    var onCode: (String) -> Void
    var onFailure: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MailboxInviteQRScannerPanel(
                onCode: { payload in
                    onCode(payload)
                    dismiss()
                },
                onFailure: { message in
                    onFailure?(message)
                    dismiss()
                }
            )
            .ignoresSafeArea(edges: .all)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    } else {
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

extension View {
    /// Zooms a presented sheet out of this view (iOS 18+).
    @ViewBuilder
    func inviteScannerTransitionSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Pairs with `inviteScannerTransitionSource` on the sheet content.
    @ViewBuilder
    func inviteScannerZoomTransition(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
