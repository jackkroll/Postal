import SwiftUI

struct LetterReaderSection: View {
    let shipmentID: String
    let letterMetadata: LetterMetadata?
    let letterService: LetterContentProviding

    @State private var content: LetterContent?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAccessDenied = false

    var body: some View {
        Section("Letter") {
            if isLoading {
                ProgressView("Loading letter…")
            } else if let content {
                LetterContentView(content: content)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            } else if isAccessDenied {
                Label("Letter not available yet", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if letterMetadata == nil {
                Text("No letter attached to this shipment.")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: shipmentID) {
            await loadLetter()
        }
    }

    private func loadLetter() async {
        guard letterMetadata != nil else { return }

        isLoading = true
        errorMessage = nil
        isAccessDenied = false
        content = nil
        defer { isLoading = false }

        do {
            content = try await letterService.fetchLetter(
                shipmentID: shipmentID,
                expectedFormat: letterMetadata?.format
            )
        } catch let error as APIError {
            switch error {
            case .httpStatus(403, _):
                isAccessDenied = true
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Text Letter") {
    Form {
        LetterReaderSection(
            shipmentID: PreviewData.deliveredTrackingNumber,
            letterMetadata: PreviewData.deliveredLetterMetadata,
            letterService: PreviewLetterContentService()
        )
    }
}
