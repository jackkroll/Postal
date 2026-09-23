import Foundation

extension APIClient {
    /// Retries `operation` on HTTP 429 with a short exponential backoff.
    ///
    /// Only worth it on routes under a generous bucket — the general 120/min limiter,
    /// or the per-user block limiter — where a 429 means a burst rather than the user
    /// reaching a real cap. Routes with a tight dedicated limiter (reports, 10/min)
    /// should surface the 429 instead, since waiting half a second cannot clear it.
    func retryingRateLimit<T>(
        attempts: Int = 3,
        _ operation: () async throws -> T
    ) async throws -> T {
        var attempt = 0
        var delay = Duration.milliseconds(500)

        while true {
            attempt += 1
            do {
                return try await operation()
            } catch {
                guard attempt < attempts,
                      (error as? APIError)?.httpStatusCode == 429
                else {
                    throw error
                }
                try await Task.sleep(for: delay)
                delay *= 2
            }
        }
    }
}
