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

/// Writable letter paper that slides out of the envelope’s top opening.
struct LetterSheetView: View {
    let isComposing: Bool
    let letterText: String
    var drawingAttached: Bool = false
    let isHighlighted: Bool
    @Binding var letterTextBinding: String
    @FocusState.Binding var isComposerFocused: Bool

    /// Static shadow — do not animate radius (expensive offscreen passes).
    private let shadowRadius: CGFloat = 12
    private let shadowY: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
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
    private var content: some View {
        if isComposing {
            TextEditor(text: $letterTextBinding)
                .focused($isComposerFocused)
                .font(.body)
                .foregroundStyle(.primary)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transaction { $0.animation = nil }
                .overlay(alignment: .topLeading) {
                    if letterTextBinding.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Write your letter…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        } else if drawingAttached {
            VStack(alignment: .leading, spacing: 8) {
                Label("Drawing attached", systemImage: "pencil.tip.crop.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Your handwritten letter is ready to send.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if !letterText.isEmpty {
            ScrollView {
                Text(letterText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            Text("Write your letter…")
                .font(.body)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
