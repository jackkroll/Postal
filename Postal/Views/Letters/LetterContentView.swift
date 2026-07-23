import SwiftUI
import PencilKit

struct LetterContentView: View {
    let content: LetterContent

    var body: some View {
        switch content {
        case let .text(text, mimeType):
            TextLetterView(text: text, mimeType: mimeType)
        case let .image(_, metadata):
            UnsupportedLetterView(format: .image, metadata: metadata)
        case let .encoded(data, metadata):
            if metadata.looksLikePKDrawing {
                PKDrawingLetterView(data: data, metadata: metadata)
            } else {
                UnsupportedLetterView(format: .encoded, metadata: metadata)
            }
        case let .pkDrawing(data, metadata):
            PKDrawingLetterView(data: data, metadata: metadata)
        }
    }
}

private struct TextLetterView: View {
    let text: String
    let mimeType: String

    private var isMarkdown: Bool {
        mimeType == "text/markdown" || mimeType.hasSuffix("/markdown")
    }

    var body: some View {
        ScrollView {
            if isMarkdown {
                Text(LocalizedStringKey(text))
            } else {
                Text(text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .padding()
    }
}

private struct PKDrawingLetterView: View {
    let data: Data
    let metadata: LetterMetadata

    var body: some View {
        Group {
            if let drawing = try? PKDrawing(data: data),
               let image = Self.render(drawing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
                    }
                    .padding()
                    .accessibilityLabel("Drawing letter")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Couldn't open drawing", systemImage: "pencil.tip.crop.circle.badge.exclamationmark")
                        .font(.headline)
                    Text(metadata.displayDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
    }

    private static func render(_ drawing: PKDrawing) -> UIImage? {
        var bounds = drawing.bounds
        if bounds.isNull || bounds.isEmpty || bounds.width < 1 || bounds.height < 1 {
            bounds = CGRect(x: 0, y: 0, width: 320, height: 420)
        } else {
            bounds = bounds.insetBy(dx: -24, dy: -24)
        }
        return drawing.image(from: bounds, scale: 2)
    }
}

private struct UnsupportedLetterView: View {
    let format: LetterFormat
    let metadata: LetterMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Preview not available", systemImage: "doc.fill")
                .font(.headline)
            Text(metadata.displayDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension LetterMetadata {
    var looksLikePKDrawing: Bool {
        if format == .pkDrawing { return true }
        let type = mimeType.lowercased()
        if type.contains("pkdrawing") || type.contains("pencilkit") { return true }
        if let filename, filename.lowercased().hasSuffix(".pkdrawing") { return true }
        return false
    }

    var displayDescription: String {
        var parts = ["\(format.rawValue) letter"]
        if let filename {
            parts.append(filename)
        }
        if let byteSize {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file))
        }
        if let encoding {
            parts.append(encoding)
        }
        return parts.joined(separator: " · ")
    }
}

#Preview("Plain Text") {
    LetterContentView(content: .text(PreviewData.sampleLetterText, mimeType: "text/plain"))
        .padding()
}

#Preview("Drawing Letter") {
    LetterContentView(content: .pkDrawing(
        PKDrawing().dataRepresentation(),
        metadata: LetterMetadata(
            format: .pkDrawing,
            mimeType: "application/x-pkdrawing",
            encoding: nil,
            filename: "letter.pkdrawing",
            byteSize: 128
        )
    ))
}

#Preview("Image Placeholder") {
    LetterContentView(content: .image(
        Data(),
        metadata: LetterMetadata(format: .image, mimeType: "image/png", encoding: nil, filename: "photo.png", byteSize: 48_291)
    ))
    .padding()
}
