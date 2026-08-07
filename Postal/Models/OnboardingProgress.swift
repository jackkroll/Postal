import Foundation

/// Ordered steps in the new-user onboarding flow.
enum OnboardingStep: String, Codable, CaseIterable, Comparable {
    case claimMailbox
    case askDestination
    case composeLetter
    case claimStamps
    case paywall

    private var sortIndex: Int {
        switch self {
        case .claimMailbox: 0
        case .askDestination: 1
        case .composeLetter: 2
        case .claimStamps: 3
        case .paywall: 4
        }
    }

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    var next: OnboardingStep? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}

enum OnboardingStatus: String, Codable, Equatable {
    case notStarted
    case inProgress
    case completed
    case skipped
}

/// Persisted per-user onboarding state (local only).
struct OnboardingProgress: Codable, Equatable {
    var status: OnboardingStatus
    var step: OnboardingStep
    /// Mailbox claimed (or already owned) during onboarding.
    var originMailboxID: MailboxID?
    var originMailboxLabel: String?
    /// Optional destination the user saved in the “have someone to write?” step.
    var savedDestination: MailboxSummary?
    var savedDestinationNickname: String?
    /// Local pending time-capsule id created in the letter step.
    var pendingTimeCapsuleID: UUID?

    static func fresh(startingAt step: OnboardingStep = .claimMailbox) -> OnboardingProgress {
        OnboardingProgress(
            status: .inProgress,
            step: step,
            originMailboxID: nil,
            originMailboxLabel: nil,
            savedDestination: nil,
            savedDestinationNickname: nil,
            pendingTimeCapsuleID: nil
        )
    }

    static var completed: OnboardingProgress {
        OnboardingProgress(
            status: .completed,
            step: .paywall,
            originMailboxID: nil,
            originMailboxLabel: nil,
            savedDestination: nil,
            savedDestinationNickname: nil,
            pendingTimeCapsuleID: nil
        )
    }
}

/// Local letter waiting to send (e.g. deferred when stamps are short).
struct PendingTimeCapsule: Codable, Identifiable, Hashable {
    let id: UUID
    var createdAt: Date
    var originMailboxID: MailboxID?
    var destinationMailboxID: MailboxID
    var destinationLabel: String
    var letterText: String
    var isSelfAddressed: Bool
    var schedulePreset: SchedulePreset

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        originMailboxID: MailboxID?,
        destinationMailboxID: MailboxID,
        destinationLabel: String,
        letterText: String,
        isSelfAddressed: Bool,
        schedulePreset: SchedulePreset = .oneMonth
    ) {
        self.id = id
        self.createdAt = createdAt
        self.originMailboxID = originMailboxID
        self.destinationMailboxID = destinationMailboxID
        self.destinationLabel = destinationLabel
        self.letterText = letterText
        self.isSelfAddressed = isSelfAddressed
        self.schedulePreset = schedulePreset
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, originMailboxID, destinationMailboxID
        case destinationLabel, letterText, isSelfAddressed, schedulePreset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        originMailboxID = try container.decodeIfPresent(MailboxID.self, forKey: .originMailboxID)
        destinationMailboxID = try container.decode(MailboxID.self, forKey: .destinationMailboxID)
        destinationLabel = try container.decode(String.self, forKey: .destinationLabel)
        letterText = try container.decode(String.self, forKey: .letterText)
        isSelfAddressed = try container.decode(Bool.self, forKey: .isSelfAddressed)
        schedulePreset = try container.decodeIfPresent(SchedulePreset.self, forKey: .schedulePreset) ?? .oneMonth
    }
}
