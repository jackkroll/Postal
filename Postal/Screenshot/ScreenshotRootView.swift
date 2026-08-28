import PencilKit
import SwiftUI

/// Offline, fixture-backed root used only when ``ScreenshotMode/isEnabled``.
struct ScreenshotRootView: View {
    let screen: ScreenshotScreen

    var body: some View {
        screenContent
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(screen.accessibilityIdentifier)
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch screen {
        case .tracking:
            NavigationStack {
                TrackingView(
                    viewmodel: .preview(
                        trackingNumber: PreviewData.inTransitTrackingNumber,
                        route: PreviewData.routeInTransit,
                        trackingInfo: PreviewData.trackingInfoInTransit,
                        letterSummary: PreviewData.letterInTransit
                    )
                )
            }

        case .addressBook:
            NavigationStack {
                AddressBook(viewmodel: .preview(), loadsOnAppear: false)
            }
            .environment(Router())

        case .compose:
            ScreenshotDrawingComposeView()

        case .timeCapsule:
            ScreenshotTimeCapsuleView()
        }
    }
}

/// Drawing composer with PencilKit tools visible for marketing shots.
private struct ScreenshotDrawingComposeView: View {
    @State private var draftSaveStatus: DraftSaveStatus = .saved

    var body: some View {
        NavigationStack {
            CanvasView(
                initialDrawingData: ScreenshotSampleDrawing.data,
                draftSaveStatus: $draftSaveStatus,
                limits: nil,
                onContinue: { _ in }
            )
        }
    }
}

/// Full-screen send confirmation with a year hold pre-selected for marketing shots.
private struct ScreenshotTimeCapsuleView: View {
    @State private var selectedTiming: LetterSendTimingOption? = .preset(.oneYear)
    @State private var customDeliverAt = Calendar.current.date(
        byAdding: .year,
        value: 1,
        to: .now
    ) ?? .now

    var body: some View {
        SendConfirmationSheet(
            stampCost: 1,
            stampBalance: 5,
            unlimitedSends: false,
            scheduling: .freeDefaults,
            routeEstimate: nil,
            isLoadingEstimate: false,
            estimateError: nil,
            selectedTiming: $selectedTiming,
            customDeliverAt: $customDeliverAt,
            onConfirm: {},
            onUpgrade: {}
        )
    }
}

/// Loads the marketing compose drawing from the bundled screenshot fixture.
private enum ScreenshotSampleDrawing {
    static let data: Data = load()

    private static func load() -> Data {
        guard let url = Bundle.main.url(forResource: "compose-letter", withExtension: "pkdrawing"),
              let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data),
              !drawing.strokes.isEmpty
        else {
            return PKDrawing().dataRepresentation()
        }
        return data
    }
}
