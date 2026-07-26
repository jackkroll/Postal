import PencilKit
import SwiftUI

enum LetterCreationRegion: Hashable {
    case destination
    case returnAddress
    case body
    case stamp
}

/// Anchors of interactive regions — resolved once at the stage (no per-region GeometryReader).
struct LetterRegionAnchorsPreferenceKey: PreferenceKey {
    static var defaultValue: [LetterCreationRegion: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [LetterCreationRegion: Anchor<CGRect>],
        nextValue: () -> [LetterCreationRegion: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Resolved frames in the stage coordinate space.
struct LetterRegionFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [LetterCreationRegion: CGRect] = [:]

    static func reduce(value: inout [LetterCreationRegion: CGRect], nextValue: () -> [LetterCreationRegion: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func letterRegion(_ region: LetterCreationRegion) -> some View {
        anchorPreference(key: LetterRegionAnchorsPreferenceKey.self, value: .bounds) { anchor in
            [region: anchor]
        }
    }
}

// MARK: - Envelope

/// Outer envelope — addresses and postage only.
struct ShippingEnvelopeView: View {
    let destination: MailboxSummary?
    let origin: MailboxSummary?
    let isStampApplied: Bool
    let isStampInteractive: Bool
    let highlightedRegion: LetterCreationRegion?
    let isDimmed: Bool
    var onDestinationTap: () -> Void
    var onOriginTap: () -> Void
    var onStampTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 56, height: 3)
                .padding(.top, 12)

            HStack(alignment: .top, spacing: 12) {
                returnAddressBlock
                    .frame(maxWidth: .infinity, alignment: .leading)

                stampBlock
                    .fixedSize(horizontal: true, vertical: true)
            }
            .padding(.horizontal, 14)

            destinationBlock
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Softer static shadow — avoid animating shadow radius with dim state.
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
        }
        .opacity(isDimmed ? 0.72 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Envelope")
    }

    private var returnAddressBlock: some View {
        Button(action: onOriginTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text("From")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let origin {
                    Text(origin.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                    Text(origin.locationLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Choose mailbox")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .contentShape(Rectangle())
            .background(regionHighlight(.returnAddress))
        }
        .buttonStyle(.plain)
        .letterRegion(.returnAddress)
        .disabled(isDimmed || (highlightedRegion != nil && highlightedRegion != .returnAddress))
        .accessibilityHint(origin == nil ? "Opens your mailboxes" : "Change return address")
    }

    private var destinationBlock: some View {
        Button(action: onDestinationTap) {
            VStack(spacing: 6) {
                Text("To")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                if let destination {
                    Text(destination.label)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                    Text(destination.locationLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Choose destination")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(regionHighlight(.destination))
        }
        .buttonStyle(.plain)
        .letterRegion(.destination)
        .disabled(isDimmed || (highlightedRegion != nil && highlightedRegion != .destination))
        .accessibilityHint(destination == nil ? "Search for a mailbox" : "Change destination")
    }

    private var stampBlock: some View {
        Button(action: onStampTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        Color(.separator).opacity(0.7),
                        style: StrokeStyle(lineWidth: 1, dash: isStampApplied ? [] : [4, 3])
                    )
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isStampApplied ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemFill).opacity(0.6))
                    }
                    .frame(width: 48, height: 60)

                if isStampApplied {
                    LetterCreationAsset.stampApplied.image
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                } else {
                    LetterCreationAsset.stampIdle.image
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isStampInteractive ? Color.accentColor : Color(.tertiaryLabel))
                }
            }
            .padding(6)
            .background(regionHighlight(.stamp))
        }
        .buttonStyle(.plain)
        .disabled(!isStampInteractive || isStampApplied)
        .letterRegion(.stamp)
        .accessibilityLabel(isStampApplied ? "Stamp applied" : "Postage stamp")
        .accessibilityHint(isStampInteractive ? "Sends the letter" : "")
    }

    private func regionHighlight(_ region: LetterCreationRegion) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(highlightedRegion == region ? Color.accentColor.opacity(0.06) : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        highlightedRegion == region ? Color.accentColor.opacity(0.35) : Color.clear,
                        lineWidth: 1.5
                    )
            }
    }
}

// MARK: - Letter sheet

/// What the letter paper shows in the guided flow.
enum LetterSheetContent: Equatable {
    /// Nothing chosen yet and the letter isn't the active step (tucked behind the envelope).
    case blank
    /// Write / draw options rendered on the paper itself.
    case chooser
    case text(String)
    case drawing(Data)
}

/// Letter paper that slides out of the envelope’s top opening.
///
/// Composing happens on dedicated pages (`LetterTextComposerView` / `CanvasView`);
/// this sheet offers the choice between them and previews whatever was written.
struct LetterSheetView: View {
    let content: LetterSheetContent
    let isHighlighted: Bool
    let isInteractive: Bool
    var warning: String?
    var onWrite: () -> Void = {}
    var onDraw: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDiscard: () -> Void = {}

    /// Static shadow — do not animate radius (expensive offscreen passes).
    private let shadowRadius: CGFloat = 12
    private let shadowY: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            paperContent
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemBackground))
                }
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.18), radius: shadowRadius, y: shadowY)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isHighlighted ? Color.accentColor.opacity(0.45) : Color(.separator).opacity(0.35),
                    lineWidth: isHighlighted ? 1.5 : 0.5
                )
        }
        .letterRegion(.body)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Letter")
    }

    @ViewBuilder
    private var paperContent: some View {
        switch content {
        case .blank:
            Text("Write your letter…")
                .font(.body)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .chooser:
            chooser
        case let .text(text):
            filledLetter {
                ScrollView {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        case let .drawing(data):
            filledLetter {
                LetterDrawingPreview(data: data)
            }
        }
    }

    private var chooser: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            composeOption(
                title: "Write",
                subtitle: "Type your letter.",
                systemImage: "square.and.pencil",
                action: onWrite
            )

            composeOption(
                title: "Draw",
                subtitle: "Handwrite or sketch it.",
                systemImage: "pencil.tip.crop.circle",
                action: onDraw
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func composeOption(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                Color.accentColor.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .accessibilityHint("Opens the \(title.lowercased()) page")
    }

    private func filledLetter(@ViewBuilder preview: () -> some View) -> some View {
        VStack(spacing: 10) {
            preview()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isInteractive {
                HStack(spacing: 12) {
                    Button("Edit", systemImage: "pencil", action: onEdit)
                        .buttonStyle(.bordered)
                    Spacer(minLength: 0)
                    Button("Start Over", systemImage: "arrow.uturn.backward", action: onDiscard)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
                .controlSize(.small)
                .labelStyle(.titleAndIcon)
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Renders PKDrawing bytes once per change so the stage doesn't rasterize on every layout pass.
private struct LetterDrawingPreview: View {
    let data: Data

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Label("Drawing attached", systemImage: "pencil.tip.crop.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .task(id: data) {
            image = Self.render(data)
        }
        .accessibilityLabel("Drawn letter")
    }

    private static func render(_ data: Data) -> UIImage? {
        guard let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty else { return nil }
        var bounds = drawing.bounds
        guard !bounds.isNull, bounds.width >= 1, bounds.height >= 1 else { return nil }
        bounds = bounds.insetBy(dx: -16, dy: -16)
        return drawing.image(from: bounds, scale: 1)
    }
}
