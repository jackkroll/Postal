import Foundation

extension APIClient {
    /// Newest first. Only reports the caller filed — a reported user sees nothing.
    ///
    /// Falls under the general per-IP limiter, so a 429 here is a burst worth
    /// riding out rather than the reporter hitting their submission cap.
    func listReports() async throws -> [SubmittedReport] {
        let response: ReportListResponse = try await retryingRateLimit {
            try await self.get(.meReports, authenticated: true)
        }
        return response.reports
    }

    /// Reports a letter's content. Only its recipient may, and only once it has
    /// arrived; a sender reporting their own letter is a 400.
    func createLetterReport(
        shipmentID: String,
        reason: ReportReason,
        details: String?
    ) async throws -> SubmittedReport {
        try await createReport(
            .letter(shipmentID: shipmentID, reason: reason, details: details)
        )
    }

    /// Reports the person who owns `mailboxID`, for behavior not tied to one letter.
    func createMailboxReport(
        mailboxID: String,
        reason: ReportReason,
        details: String?
    ) async throws -> SubmittedReport {
        try await createReport(
            .mailbox(mailboxID: mailboxID, reason: reason, details: details)
        )
    }

    /// Idempotent per target: one row per letter and one per reported account. A repeat
    /// submission returns the *original* record — original reason, details, and
    /// `created_at` — still under a 201, so callers must render what comes back rather
    /// than what they sent.
    ///
    /// Not retried on 429: this route uses the dedicated report limiter (10/min per
    /// user), where backing off a few hundred milliseconds cannot help.
    private func createReport(_ request: CreateReportRequest) async throws -> SubmittedReport {
        try await post(.createReport, body: request, authenticated: true)
    }
}
