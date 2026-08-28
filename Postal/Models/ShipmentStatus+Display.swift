import SwiftUI

extension ShipmentStatus {
    var displayTitle: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Delivered or failed — shown under Completed, not in the active list.
    var isTerminal: Bool {
        self == .delivered || self == .failed
    }

    var iconName: String {
        switch self {
        case .awaitingPickup: "tray.full.fill"
        case .inTransit: "truck.box.fill"
        case .atFacility: "building.fill"
        case .held: "lock.fill"
        case .outForDelivery: "truck.box.badge.clock.fill"
        case .delivered: "house.fill"
        case .failed: "xmark"
        }
    }

    var tintColor: Color {
        switch self {
        case .awaitingPickup: .teal
        case .inTransit, .atFacility: .blue
        case .held: .indigo
        case .outForDelivery: .mint
        case .delivered: .green
        case .failed: .red
        }
    }
}

extension LetterFormat {
    var displayTitle: String {
        switch self {
        case .text: "Text letter"
        case .image: "Image letter"
        case .encoded: "Encoded letter"
        case .pkDrawing: "Drawing letter"
        }
    }
}
