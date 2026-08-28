import Foundation

/// Launch-argument driven App Store screenshot staging.
///
/// Enabled when Fastlane Snapshot passes `-FASTLANE_SNAPSHOT` (or explicit `-ScreenshotMode`).
/// Choose the screen with `-ScreenshotScreen` followed by one of ``ScreenshotScreen`` raw values.
enum ScreenshotMode {
    /// Hide `#if DEBUG` developer affordances while capturing marketing screenshots.
    static var hidesDeveloperUI: Bool { isEnabled }

    static var isEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ScreenshotMode") { return true }
        if let index = args.firstIndex(of: "-FASTLANE_SNAPSHOT") {
            let next = args.indices.contains(index + 1) ? args[index + 1] : "YES"
            return next.uppercased() != "NO"
        }
        return false
    }

    static var screen: ScreenshotScreen {
        guard let value = argumentValue(for: "-ScreenshotScreen"),
              let screen = ScreenshotScreen(rawValue: value) else {
            return .tracking
        }
        return screen
    }

    private static func argumentValue(for name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: name),
              args.indices.contains(index + 1) else {
            return nil
        }
        return args[index + 1]
    }
}

enum ScreenshotScreen: String, CaseIterable {
    case tracking
    case addressBook
    case compose
    case timeCapsule

    /// Snapshot / Frameit filename stem (ordered for App Store scroll).
    var snapshotName: String {
        switch self {
        case .tracking: "01_Tracking"
        case .addressBook: "02_AddressBook"
        case .compose: "03_Compose"
        case .timeCapsule: "04_TimeCapsule"
        }
    }

    var accessibilityIdentifier: String {
        "screenshot.\(rawValue)"
    }
}
