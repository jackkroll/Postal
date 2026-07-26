import Foundation
import RevenueCat

/// Keeps RevenueCat's app user ID aligned with Firebase Auth.
///
/// Identity work is serialized and runs in a detached task so SwiftUI `.task`
/// cancellation cannot abandon `logIn` and leave RC on an anonymous ID.
actor PurchasesIdentityService {
    private var inFlight: Task<Bool, Never>?
    private var desiredUserID: String?
    private var hasDesiredUserID = false
    private var generation = 0

    /// Latest sync outcome for the Settings debug screen.
    private(set) var lastSyncAt: Date?
    private(set) var lastSyncSucceeded: Bool?
    private(set) var lastSyncErrorMessage: String?
    private(set) var lastSyncedFirebaseUserID: String?

    /// Sync RC identity to `firebaseUserID` (nil = signed out / anonymous).
    /// Concurrent callers coalesce onto the latest desired identity.
    @discardableResult
    func sync(firebaseUserID: String?) async -> Bool {
        if hasDesiredUserID,
           desiredUserID == firebaseUserID,
           let inFlight {
            return await awaitInFlight(inFlight)
        }

        if isAligned(with: firebaseUserID) {
            hasDesiredUserID = true
            desiredUserID = firebaseUserID
            recordSuccess(firebaseUserID: firebaseUserID)
            return true
        }

        hasDesiredUserID = true
        desiredUserID = firebaseUserID
        generation &+= 1
        let gen = generation

        inFlight?.cancel()
        let task = Task.detached { [self] in
            await self.performSync(generation: gen)
        }
        inFlight = task
        return await awaitInFlight(task)
    }

    /// Snapshot of identity-service state for debugging.
    func diagnostics() -> PurchasesIdentityDiagnostics {
        PurchasesIdentityDiagnostics(
            desiredFirebaseUserID: hasDesiredUserID ? desiredUserID : nil,
            hasDesiredUserID: hasDesiredUserID,
            lastSyncedFirebaseUserID: lastSyncedFirebaseUserID,
            lastSyncAt: lastSyncAt,
            lastSyncSucceeded: lastSyncSucceeded,
            lastSyncErrorMessage: lastSyncErrorMessage,
            isSyncInFlight: inFlight.map { !$0.isCancelled } ?? false
        )
    }

    /// True when RC already matches the given Firebase uid (or anonymous when nil).
    nonisolated func isAligned(with firebaseUserID: String?) -> Bool {
        guard Purchases.isConfigured else { return false }
        if let firebaseUserID {
            return Purchases.shared.appUserID == firebaseUserID
        }
        return Purchases.shared.isAnonymous
    }

    /// Wait for a detached identity task without cancelling it if the caller is cancelled.
    private func awaitInFlight(_ task: Task<Bool, Never>) async -> Bool {
        await task.value
    }

    private func performSync(generation gen: Int) async -> Bool {
        var lastError: String?

        for attempt in 1...3 {
            guard gen == generation else { return false }
            guard hasDesiredUserID else { return false }

            let target = desiredUserID
            if isAligned(with: target) {
                recordSuccess(firebaseUserID: target)
                return true
            }

            do {
                if let userID = target {
                    _ = try await Purchases.shared.logIn(userID)
                } else if !Purchases.shared.isAnonymous {
                    _ = try await Purchases.shared.logOut()
                }
            } catch is CancellationError {
                // Only the superseded inFlight cancel should land here.
                let aligned = gen == generation && isAligned(with: target)
                if aligned {
                    recordSuccess(firebaseUserID: target)
                }
                return aligned
            } catch {
                // logOut throws when already anonymous; treat as success.
                if target == nil, Purchases.shared.isAnonymous {
                    recordSuccess(firebaseUserID: nil)
                    return true
                }
                lastError = error.localizedDescription
                if attempt < 3 {
                    try? await Task.sleep(for: .milliseconds(200 * attempt))
                    continue
                }
                let aligned = isAligned(with: target)
                if aligned {
                    recordSuccess(firebaseUserID: target)
                } else {
                    recordFailure(firebaseUserID: target, message: lastError)
                }
                return aligned
            }

            if isAligned(with: target) {
                recordSuccess(firebaseUserID: target)
                return true
            }

            lastError = "RC appUserID still \(Purchases.shared.appUserID) after logIn/logOut"
            if attempt < 3 {
                try? await Task.sleep(for: .milliseconds(200 * attempt))
            }
        }

        guard gen == generation, hasDesiredUserID else { return false }
        let aligned = isAligned(with: desiredUserID)
        if aligned {
            recordSuccess(firebaseUserID: desiredUserID)
        } else {
            recordFailure(firebaseUserID: desiredUserID, message: lastError)
        }
        return aligned
    }

    private func recordSuccess(firebaseUserID: String?) {
        lastSyncedFirebaseUserID = firebaseUserID
        lastSyncAt = Date()
        lastSyncSucceeded = true
        lastSyncErrorMessage = nil
    }

    private func recordFailure(firebaseUserID: String?, message: String?) {
        lastSyncedFirebaseUserID = firebaseUserID
        lastSyncAt = Date()
        lastSyncSucceeded = false
        lastSyncErrorMessage = message
    }
}

struct PurchasesIdentityDiagnostics: Sendable {
    var desiredFirebaseUserID: String?
    var hasDesiredUserID: Bool
    var lastSyncedFirebaseUserID: String?
    var lastSyncAt: Date?
    var lastSyncSucceeded: Bool?
    var lastSyncErrorMessage: String?
    var isSyncInFlight: Bool
}
