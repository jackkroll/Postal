import SwiftUI

/// SF Symbol names for the interactive letter creation UI.
/// Swap `systemName` (or add an `Image` asset path) without touching the phase machine.
enum LetterCreationAsset: Hashable {
    case stampIdle
    case stampApplied
    case writingCue
    case envelope
    case destinationCue
    case returnAddressCue

    var systemName: String {
        switch self {
        case .stampIdle:
            return "postageStamp"
        case .stampApplied:
            return "postageStamp.fill"
        case .writingCue:
            return "square.and.pencil"
        case .envelope:
            return "envelope.fill"
        case .destinationCue:
            return "tray"
        case .returnAddressCue:
            return "person.crop.circle"
        }
    }

    var image: Image {
        Image(systemName: systemName)
    }
}
