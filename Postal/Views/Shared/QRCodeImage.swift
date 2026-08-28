import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum QRCodeImage {
    /// Renders a QR code for `string` on a background queue. Returns nil if generation fails.
    static func make(from string: String, scale: CGFloat = 12) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            await makeSync(from: string, scale: scale)
        }.value
    }

    /// Synchronous render — prefer `make(from:)` off the main thread for UI.
    static func makeSync(from string: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
