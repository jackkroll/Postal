import Foundation

/// Local snapshot of an in-progress letter in the guided ship flow.
struct LetterDraft: Codable, Identifiable, Hashable {
    let id: UUID
    var updatedAt: Date
    var phase: LetterCreationPhase
    var composeKind: LetterComposeKind?
    var originMailboxID: MailboxID?
    var destination: MailboxSummary?
    var letterText: String
    var hasDrawing: Bool

    init(
        id: UUID = UUID(),
        updatedAt: Date = .now,
        phase: LetterCreationPhase = .destination,
        composeKind: LetterComposeKind? = nil,
        originMailboxID: MailboxID? = nil,
        destination: MailboxSummary? = nil,
        letterText: String = "",
        hasDrawing: Bool = false
    ) {
        self.id = id
        self.updatedAt = updatedAt
        self.phase = phase
        self.composeKind = composeKind
        self.originMailboxID = originMailboxID
        self.destination = destination
        self.letterText = letterText
        self.hasDrawing = hasDrawing
    }

    var destinationTitle: String {
        destination?.label ?? "No destination"
    }

    var formatHint: String? {
        switch composeKind {
        case .text: "Write"
        case .drawing: "Draw"
        case nil: nil
        }
    }
}
