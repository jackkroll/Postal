import Foundation
import Observation

/// Loads and persists onboarding progress keyed by Firebase user id.
@Observable
final class OnboardingStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var userID: String?
    private(set) var progress: OnboardingProgress?

    /// True when signed-in progress exists and is not finished.
    var shouldPresent: Bool {
        guard let progress else { return false }
        switch progress.status {
        case .inProgress, .notStarted:
            return true
        case .completed, .skipped:
            return false
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userID: String) {
        self.userID = userID
        progress = read(userID: userID)
    }

    func clear() {
        userID = nil
        progress = nil
    }

    /// First launch for this uid: start onboarding if they have no mailbox; otherwise grandfather as completed.
    @MainActor
    func bootstrapIfNeeded(ownedMailboxCount: Int) {
        guard let userID else { return }
        if progress != nil { return }

        if ownedMailboxCount > 0 {
            let done = OnboardingProgress.completed
            progress = done
            write(done, userID: userID)
        } else {
            let fresh = OnboardingProgress.fresh(startingAt: .claimMailbox)
            progress = fresh
            write(fresh, userID: userID)
        }
    }

    /// Skip claim step when the user already owns a mailbox (e.g. claimed outside onboarding).
    func skipClaimIfNeeded(ownedMailboxes: [MailboxSummary]) {
        guard var progress, progress.status == .inProgress || progress.status == .notStarted else { return }
        guard progress.step == .claimMailbox, let first = ownedMailboxes.first else { return }
        progress.originMailboxID = first.id
        progress.originMailboxLabel = first.label
        progress.step = .askDestination
        progress.status = .inProgress
        commit(progress)
    }

    func recordClaimedMailbox(_ mailbox: MailboxSummary) {
        guard var progress else { return }
        progress.originMailboxID = mailbox.id
        progress.originMailboxLabel = mailbox.label
        progress.step = .askDestination
        progress.status = .inProgress
        commit(progress)
    }

    func recordDestinationSkipped() {
        advance(to: .composeLetter)
    }

    func recordSavedDestination(_ mailbox: MailboxSummary, nickname: String?) {
        guard var progress else { return }
        progress.savedDestination = mailbox
        progress.savedDestinationNickname = nickname
        progress.step = .composeLetter
        progress.status = .inProgress
        commit(progress)
    }

    func recordPendingTimeCapsule(id: UUID) {
        guard var progress else { return }
        progress.pendingTimeCapsuleID = id
        progress.step = .claimStamps
        progress.status = .inProgress
        commit(progress)
    }

    func recordLetterStepFinished() {
        advance(to: .claimStamps)
    }

    func recordStampsStepFinished() {
        advance(to: .paywall)
    }

    func complete() {
        guard var progress else { return }
        progress.status = .completed
        progress.step = .paywall
        commit(progress)
    }

    func skipRemaining() {
        guard var progress else { return }
        progress.status = .skipped
        commit(progress)
    }

    func advance(to step: OnboardingStep) {
        guard var progress else { return }
        progress.step = step
        progress.status = .inProgress
        commit(progress)
    }

    /// Clears persisted progress and restarts onboarding from the first step (DEBUG / QA).
    func resetProgressForDebug(startingAt step: OnboardingStep = .claimMailbox) {
        guard let userID else { return }
        let fresh = OnboardingProgress.fresh(startingAt: step)
        progress = fresh
        write(fresh, userID: userID)
    }

    /// Removes all stored progress for the current user so the next bootstrap can run again.
    func clearProgressForDebug() {
        guard let userID else {
            progress = nil
            return
        }
        defaults.removeObject(forKey: storageKey(userID: userID))
        progress = nil
    }

    // MARK: - Persistence

    private func storageKey(userID: String) -> String {
        "onboarding.progress.\(userID)"
    }

    private func read(userID: String) -> OnboardingProgress? {
        guard let data = defaults.data(forKey: storageKey(userID: userID)) else { return nil }
        return try? decoder.decode(OnboardingProgress.self, from: data)
    }

    private func write(_ progress: OnboardingProgress, userID: String) {
        guard let data = try? encoder.encode(progress) else { return }
        defaults.set(data, forKey: storageKey(userID: userID))
    }

    private func commit(_ progress: OnboardingProgress) {
        self.progress = progress
        guard let userID else { return }
        write(progress, userID: userID)
    }

    /// Replaces progress for previews / debug tooling.
    func replaceProgress(_ progress: OnboardingProgress) {
        commit(progress)
    }
}
