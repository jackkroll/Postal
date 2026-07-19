import SwiftUI

struct LetterContentView: View {
    let content: LetterContent

    var body: some View {
        switch content {
        case let .text(text, mimeType):
            TextLetterView(text: text, mimeType: mimeType)
        case let .image(_, metadata):
            UnsupportedLetterView(format: .image, metadata: metadata)
        case let .encoded(_, metadata):
            UnsupportedLetterView(format: .encoded, metadata: metadata)
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

private struct UnsupportedLetterView: View {
    let format: LetterFormat
    let metadata: LetterMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Preview not available", systemImage: "doc.fill")
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var description: String {
        var parts = ["\(format.rawValue) letter"]
        if let filename = metadata.filename {
            parts.append(filename)
        }
        if let byteSize = metadata.byteSize {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file))
        }
        if let encoding = metadata.encoding {
            parts.append(encoding)
        }
        return parts.joined(separator: " · ")
    }
}

#Preview("Plain Text") {
    LetterContentView(content: .text(PreviewData.sampleLetterText, mimeType: "text/plain"))
        .padding()
}

#Preview("Image Placeholder") {
    LetterContentView(content: .image(
        Data(),
        metadata: LetterMetadata(format: .image, mimeType: "image/png", encoding: nil, filename: "photo.png", byteSize: 48_291)
    ))
    .padding()
}
