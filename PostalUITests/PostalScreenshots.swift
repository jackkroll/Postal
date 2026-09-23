import XCTest

final class PostalScreenshots: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshots() throws {
        for screen in ScreenshotScreen.allCases {
            let app = XCUIApplication()
            setupSnapshot(app)
            XCUIDevice.shared.appearance = .dark
            app.launchArguments += [
                "-FASTLANE_SNAPSHOT", "YES",
                "-ScreenshotScreen", screen.rawValue,
                "-AppleLanguages", "(en-US)",
                "-AppleLocale", "en_US",
            ]
            app.launch()

            let marker = app.descendants(matching: .any)[screen.accessibilityIdentifier]
            XCTAssertTrue(
                marker.waitForExistence(timeout: 20),
                "Expected screenshot screen \(screen.rawValue) to appear"
            )

            // Allow MapKit / PencilKit tool picker to settle.
            let settle: TimeInterval = switch screen {
            case .tracking, .compose: 2.0
            case .addressBook, .timeCapsule: 0.8
            }
            RunLoop.current.run(until: Date().addingTimeInterval(settle))

            snapshot(screen.snapshotName)
            app.terminate()
        }
    }
}

/// Mirrors app ``ScreenshotScreen`` raw values so UITests do not depend on app sources.
private enum ScreenshotScreen: String, CaseIterable {
    case tracking
    case addressBook
    case compose
    case timeCapsule

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
