import SwiftUI

/// Drives reporting and blocking as one flow.
///
/// The two are independent server-side — a report never stops mail, a block never
/// reaches a moderator — so whichever the user picks, the flow offers the other one
/// afterwards. Both live in a single presentation because that offer is what makes
/// it work: handing off between two `.sheet` modifiers drops the second one.
@Observable
final class ModerationFlow {
    enum Page: Hashable {
        case report(ReportTarget)
        case reportFiled(ReportSubmission, blockOffer: BlockOffer)
        case block(MailboxSummary)
        /// `reportTarget` is nil when the address was already reported.
        case blocked(BlockedAddress, requested: MailboxSummary, reportTarget: ReportTarget?)

        /// Whether a report can be followed by a block, and if not, whether that is
        /// worth explaining.
        enum BlockOffer: Hashable {
            case available(MailboxSummary)
            /// The letter's sender origin box was never recorded, so there is no
            /// address to block — worth saying, since the user asked for one.
            case unknownSender
            /// Already blocked, or the caller's own address. Nothing to offer and
            /// nothing to explain.
            case unnecessary
        }
    }

    var isPresented = false
    private(set) var page: Page?
    private(set) var isSubmitting = false
    /// Shown inside the sheet, which stays up so the user can retry.
    private(set) var sheetErrorMessage: String?
    /// Shown as an alert instead, for the refusals caught before the sheet opens.
    var alertMessage: String?

    /// Set by hosts that know the caller's own addresses, so reporting or blocking
    /// yourself is caught without a round trip.
    var ownedMailboxIDs: Set<MailboxID> = []

    private let reports: ReportService
    private let blocks: BlockService

    init(
        reports: ReportService = AppServices.reports,
        blocks: BlockService = AppServices.blocks
    ) {
        self.reports = reports
        self.blocks = blocks
    }

    // MARK: Entry points

    @MainActor
    func beginReport(_ target: ReportTarget) {
        switch target {
        case let .mailbox(mailbox) where ownedMailboxIDs.contains(mailbox.id):
            alertMessage = ReportText.selfMailbox
            return
        case let .letter(_, sender?, _) where ownedMailboxIDs.contains(sender):
            // A self-addressed time capsule, where the reporter is also the sender.
            alertMessage = ReportText.selfLetter
            return
        default:
            break
        }

        // Re-submitting would just hand back the original row, so skip straight to it
        // rather than collecting a reason that will be discarded.
        if let existing = reports.existingReport(for: target) {
            present(.reportFiled(
                ReportSubmission(report: existing, wasAlreadyFiled: true),
                blockOffer: blockOffer(for: target, filed: existing)
            ))
        } else {
            present(.report(target))
        }
    }

    @MainActor
    func beginBlock(_ mailbox: MailboxSummary) {
        guard !ownedMailboxIDs.contains(mailbox.id) else {
            alertMessage = BlockText.selfBlock
            return
        }
        present(.block(mailbox))
    }

    // MARK: Submission

    @MainActor
    func submitReport(_ target: ReportTarget, reason: ReportReason, details: String?) async {
        isSubmitting = true
        sheetErrorMessage = nil
        defer { isSubmitting = false }

        do {
            let submission = try await reports.submit(target, reason: reason, details: details)
            page = .reportFiled(
                submission,
                blockOffer: blockOffer(for: target, filed: submission.report)
            )
        } catch {
            guard !error.isPostalCancellation else { return }
            sheetErrorMessage = ReportService.reportFailureMessage(error)
        }
    }

    @MainActor
    func confirmBlock(_ mailbox: MailboxSummary) async {
        isSubmitting = true
        sheetErrorMessage = nil
        defer { isSubmitting = false }

        do {
            let created = try await blocks.block(mailboxID: mailbox.id)
            page = .blocked(
                created,
                requested: mailbox,
                reportTarget: reportTarget(afterBlocking: mailbox)
            )
        } catch {
            guard !error.isPostalCancellation else { return }
            sheetErrorMessage = BlockService.blockFailureMessage(error)
        }
    }

    // MARK: Crossing over

    @MainActor
    func continueToBlock() {
        guard case let .reportFiled(_, .available(mailbox)) = page else { return }
        sheetErrorMessage = nil
        page = .block(mailbox)
    }

    @MainActor
    func continueToReport() {
        guard case let .blocked(_, _, reportTarget?) = page else { return }
        sheetErrorMessage = nil
        page = .report(reportTarget)
    }

    @MainActor
    func finish() {
        isPresented = false
    }

    /// Clears the page on dismissal so a swipe-down doesn't leave the last one behind
    /// to flash on the next presentation.
    @MainActor
    func reset() {
        page = nil
        isSubmitting = false
        sheetErrorMessage = nil
    }

    // MARK: Helpers

    @MainActor
    private func present(_ page: Page) {
        sheetErrorMessage = nil
        isSubmitting = false
        self.page = page
        isPresented = true
    }

    private func blockOffer(for target: ReportTarget, filed: SubmittedReport) -> Page.BlockOffer {
        let candidate: MailboxSummary?
        switch target {
        case let .letter(_, sender, senderLabel):
            // The filed report echoes the sender's origin box, which beats whatever the
            // screen had — though it is null on shipments predating origin tracking.
            let origin = filed.parsedMailboxID ?? sender
            candidate = origin.map { .unresolved($0, label: $0 == sender ? senderLabel : nil) }
        case let .mailbox(mailbox):
            candidate = mailbox
        }

        guard let candidate else { return .unknownSender }
        guard !ownedMailboxIDs.contains(candidate.id), !blocks.isBlocked(candidate.id) else {
            return .unnecessary
        }
        return .available(candidate)
    }

    /// A mailbox report against the address just blocked, unless it is already reported.
    private func reportTarget(afterBlocking mailbox: MailboxSummary) -> ReportTarget? {
        let target = ReportTarget.mailbox(mailbox)
        return reports.existingReport(for: target) == nil ? target : nil
    }
}

extension ModerationFlow {
    /// Preview seam: drops the flow onto a given page without going through a
    /// submission, so every step can be rendered on its own.
    func showForPreview(_ page: Page, errorMessage: String? = nil) {
        self.page = page
        sheetErrorMessage = errorMessage
        isPresented = true
    }
}

extension View {
    /// Hosts the report/block sheet, plus the alert for refusals caught before it opens.
    func moderationFlow(_ flow: ModerationFlow) -> some View {
        sheet(isPresented: Binding(
            get: { flow.isPresented },
            set: { flow.isPresented = $0 }
        ), onDismiss: {
            flow.reset()
        }) {
            ModerationSheet(flow: flow)
        }
        .alert(
            ReportText.actionAlertTitle,
            isPresented: Binding(
                get: { flow.alertMessage != nil },
                set: { if !$0 { flow.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { flow.alertMessage = nil }
        } message: {
            Text(flow.alertMessage ?? "")
        }
    }
}
