import Foundation

/// Shared list of reports the signed-in user filed, so the letter screens and the
/// address book can all show an "already reported" state without each refetching
/// `GET /api/me/reports`.
///
/// Reporting is a moderation log, not enforcement. Nothing here cancels mail or
/// prevents a future send — that is `BlockService`, deliberately independent.
@Observable
final class ReportService {
    private(set) var reports: [SubmittedReport] = []
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var loadFailure: PostalLoadFailure?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func report(forLetter shipmentID: String) -> SubmittedReport? {
        reports.first { $0.matches(shipmentID: shipmentID) }
    }

    /// The mailbox report covering `mailboxID`, if that exact address is the one on
    /// record. Reports are filed against the *person*, so someone reported through
    /// another of their mailboxes has no match here — absence proves nothing.
    func report(forMailbox mailboxID: MailboxID) -> SubmittedReport? {
        reports.first { $0.matches(mailboxID: mailboxID) }
    }

    func existingReport(for target: ReportTarget) -> SubmittedReport? {
        switch target {
        case let .letter(shipmentID, _, _): report(forLetter: shipmentID)
        case let .mailbox(mailbox): report(forMailbox: mailbox.id)
        }
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            reports = try await api.listReports()
            loadFailure = nil
            hasLoaded = true
        } catch {
            guard !error.isPostalCancellation else { return }
            loadFailure = error.postalLoadFailure
        }
    }

    @MainActor
    @discardableResult
    func submit(
        _ target: ReportTarget,
        reason: ReportReason,
        details: String?
    ) async throws -> ReportSubmission {
        let filed: SubmittedReport
        switch target {
        case let .letter(shipmentID, _, _):
            filed = try await api.createLetterReport(
                shipmentID: shipmentID,
                reason: reason,
                details: details
            )
        case let .mailbox(mailbox):
            filed = try await api.createMailboxReport(
                mailboxID: mailbox.id.rawValue,
                reason: reason,
                details: details
            )
        }

        // Submission is idempotent per target, so a repeat returns the original row
        // and silently discards the reason just sent. An id already on the list, or a
        // reason that came back different from the one submitted, both mean that.
        let wasAlreadyFiled = reports.contains { $0.id == filed.id } || filed.reason != reason
        apply(filed)
        return ReportSubmission(report: filed, wasAlreadyFiled: wasAlreadyFiled)
    }

    @MainActor
    func clear() {
        reports = []
        hasLoaded = false
        loadFailure = nil
    }

    /// Adopts a list fetched elsewhere (previews, or a caller that already holds a
    /// fresher server response) without another round trip.
    func replaceAll(_ reports: [SubmittedReport]) {
        self.reports = reports
        hasLoaded = true
        loadFailure = nil
    }

    /// Newest first, matching the server's ordering, so a re-filed report keeps its
    /// original position rather than jumping to the top.
    @MainActor
    private func apply(_ report: SubmittedReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            reports[index] = report
        } else {
            reports.insert(report, at: 0)
        }
    }
}

/// The outcome of a submission, which is not always a newly filed report.
struct ReportSubmission: Hashable {
    let report: SubmittedReport
    /// True when the server handed back a report already on file, meaning the reason
    /// and details just submitted were discarded.
    let wasAlreadyFiled: Bool
}

extension ReportService {
    static func reportFailureMessage(_ error: Error) -> String {
        switch (error as? APIError)?.httpStatusCode {
        case 400:
            return badRequestMessage(error)
        case 404:
            // Also what an unrelated user probing for a letter gets, by design.
            return ReportText.letterNotFound
        case 429:
            return ReportText.rateLimited
        default:
            return connectivityMessage(error) ?? ReportText.reportFailed
        }
    }

    /// The 400s worth repeating are the ones about who may report what. The rest
    /// ("provide exactly one of…") describe a malformed request and mean nothing to
    /// a reader, so they collapse into the generic failure.
    private static func badRequestMessage(_ error: Error) -> String {
        guard case let .httpStatus(_, message?, _)? = error as? APIError else {
            return ReportText.reportFailed
        }
        if message.localizedCaseInsensitiveContains("own letter") { return ReportText.selfLetter }
        if message.localizedCaseInsensitiveContains("own mailbox") { return ReportText.selfMailbox }
        if message.localizedCaseInsensitiveContains("not arrived") { return ReportText.notArrived }
        if message.localizedCaseInsensitiveContains("unknown mailbox") { return ReportText.unknownMailbox }
        return ReportText.reportFailed
    }

    /// Offline / server-down wording is worth surfacing; everything else gets
    /// action-specific copy instead of a raw `detail`.
    private static func connectivityMessage(_ error: Error) -> String? {
        let failure = error.postalLoadFailure
        return failure.kind == .other ? nil : failure.message
    }
}
