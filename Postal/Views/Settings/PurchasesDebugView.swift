import RevenueCat
import SwiftUI
import UIKit

/// Settings submenu for inspecting Firebase ↔ RevenueCat identity alignment.
struct PurchasesDebugView: View {
    @State private var snapshot = PurchasesDebugSnapshot.empty
    @State private var isRefreshing = false
    @State private var isResyncing = false
    @State private var actionMessage: String?

    var body: some View {
        Form {
            identitySection
            customerInfoSection
            stampsSection
            syncSection
            actionsSection

            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("RevenueCat Debug")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private var identitySection: some View {
        Section {
            debugRow("Firebase UID", snapshot.firebaseUserID)
            debugRow("RC appUserID", snapshot.rcAppUserID)
            LabeledContent("RC configured", value: snapshot.isConfigured ? "Yes" : "No")
            LabeledContent("RC anonymous", value: snapshot.isAnonymous ? "Yes" : "No")
            LabeledContent("IDs aligned") {
                Text(snapshot.isAligned ? "Yes" : "No")
                    .foregroundStyle(snapshot.isAligned ? .green : .red)
                    .fontWeight(.semibold)
            }
            debugRow("Original app user ID", snapshot.originalAppUserID)
        } header: {
            Text("Identity")
        } footer: {
            Text(
                snapshot.isAligned
                    ? "Firebase UID matches RevenueCat’s current app user ID."
                    : "Mismatch: STAMP balance and Plus may be read for the wrong RC customer."
            )
        }
    }

    private var customerInfoSection: some View {
        Section("Customer Info") {
            debugRow("Active entitlements", snapshot.activeEntitlements)
            debugRow("Active subscriptions", snapshot.activeSubscriptions)
            debugRow("All purchased products", snapshot.allPurchasedProducts)
            if let firstSeen = snapshot.firstSeen {
                LabeledContent("First seen", value: firstSeen.formatted(date: .abbreviated, time: .shortened))
            } else {
                LabeledContent("First seen", value: "—")
            }
            if let requestDate = snapshot.requestDate {
                LabeledContent("Fetched at", value: requestDate.formatted(date: .abbreviated, time: .standard))
            } else {
                LabeledContent("Fetched at", value: "—")
            }
            if let error = snapshot.customerInfoError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var stampsSection: some View {
        Section("Virtual Currency") {
            LabeledContent(
                AppConfiguration.stampVirtualCurrencyCode,
                value: snapshot.stampBalance.map(String.init) ?? "—"
            )
            if let error = snapshot.stampBalanceError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var syncSection: some View {
        Section("Identity Sync") {
            debugRow("Desired Firebase UID", snapshot.desiredFirebaseUserID)
            debugRow("Last synced Firebase UID", snapshot.lastSyncedFirebaseUserID)
            LabeledContent("Last sync OK") {
                Text(snapshot.lastSyncSucceededTitle)
                    .foregroundStyle(snapshot.lastSyncSucceededColor)
            }
            if let lastSyncAt = snapshot.lastSyncAt {
                LabeledContent("Last sync at", value: lastSyncAt.formatted(date: .abbreviated, time: .standard))
            } else {
                LabeledContent("Last sync at", value: "—")
            }
            LabeledContent("Sync in flight", value: snapshot.isSyncInFlight ? "Yes" : "No")
            if let error = snapshot.lastSyncErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Task { await refresh() }
            } label: {
                if isRefreshing {
                    HStack {
                        ProgressView()
                        Text("Refreshing…")
                    }
                } else {
                    Label("Refresh Snapshot", systemImage: "arrow.clockwise")
                }
            }
            .disabled(isRefreshing || isResyncing)

            Button {
                Task { await resyncIdentity() }
            } label: {
                if isResyncing {
                    HStack {
                        ProgressView()
                        Text("Resyncing…")
                    }
                } else {
                    Label("Force RC logIn (Firebase UID)", systemImage: "person.badge.key")
                }
            }
            .disabled(isRefreshing || isResyncing || snapshot.firebaseUserID == nil)

            Button {
                copyIDs()
            } label: {
                Label("Copy IDs", systemImage: "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private func debugRow(_ title: String, _ value: String?) -> some View {
        LabeledContent(title) {
            Text(value ?? "—")
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        snapshot = await PurchasesDebugSnapshot.capture()
    }

    @MainActor
    private func resyncIdentity() async {
        guard let firebaseUserID = snapshot.firebaseUserID ?? AppServices.auth.currentUserID else {
            actionMessage = "No Firebase UID available."
            return
        }
        isResyncing = true
        defer { isResyncing = false }

        let aligned = await AppServices.purchasesIdentity.sync(firebaseUserID: firebaseUserID)
        snapshot = await PurchasesDebugSnapshot.capture()
        actionMessage = aligned
            ? "Force sync succeeded — IDs aligned."
            : "Force sync finished but IDs are still misaligned."
        if aligned {
            await AppServices.entitlements.refresh()
        }
    }

    private func copyIDs() {
        let text = """
        Firebase UID: \(snapshot.firebaseUserID ?? "—")
        RC appUserID: \(snapshot.rcAppUserID ?? "—")
        Original app user ID: \(snapshot.originalAppUserID ?? "—")
        Aligned: \(snapshot.isAligned)
        """
        UIPasteboard.general.string = text
        actionMessage = "Copied Firebase + RC IDs."
    }
}

struct PurchasesDebugSnapshot: Sendable {
    var firebaseUserID: String?
    var rcAppUserID: String?
    var isConfigured: Bool
    var isAnonymous: Bool
    var isAligned: Bool
    var originalAppUserID: String?
    var activeEntitlements: String?
    var activeSubscriptions: String?
    var allPurchasedProducts: String?
    var firstSeen: Date?
    var requestDate: Date?
    var customerInfoError: String?
    var stampBalance: Int?
    var stampBalanceError: String?
    var desiredFirebaseUserID: String?
    var lastSyncedFirebaseUserID: String?
    var lastSyncAt: Date?
    var lastSyncSucceeded: Bool?
    var lastSyncErrorMessage: String?
    var isSyncInFlight: Bool

    static let empty = PurchasesDebugSnapshot(
        firebaseUserID: nil,
        rcAppUserID: nil,
        isConfigured: false,
        isAnonymous: true,
        isAligned: false,
        originalAppUserID: nil,
        activeEntitlements: nil,
        activeSubscriptions: nil,
        allPurchasedProducts: nil,
        firstSeen: nil,
        requestDate: nil,
        customerInfoError: nil,
        stampBalance: nil,
        stampBalanceError: nil,
        desiredFirebaseUserID: nil,
        lastSyncedFirebaseUserID: nil,
        lastSyncAt: nil,
        lastSyncSucceeded: nil,
        lastSyncErrorMessage: nil,
        isSyncInFlight: false
    )

    var lastSyncSucceededTitle: String {
        switch lastSyncSucceeded {
        case true: return "Yes"
        case false: return "No"
        case nil: return "—"
        }
    }

    var lastSyncSucceededColor: Color {
        switch lastSyncSucceeded {
        case true: return .green
        case false: return .red
        case nil: return .secondary
        }
    }

    @MainActor
    static func capture() async -> PurchasesDebugSnapshot {
        let firebaseUserID = AppServices.auth.currentUserID
        let diagnostics = await AppServices.purchasesIdentity.diagnostics()

        var snapshot = PurchasesDebugSnapshot.empty
        snapshot.firebaseUserID = firebaseUserID
        snapshot.desiredFirebaseUserID = diagnostics.desiredFirebaseUserID
        snapshot.lastSyncedFirebaseUserID = diagnostics.lastSyncedFirebaseUserID
        snapshot.lastSyncAt = diagnostics.lastSyncAt
        snapshot.lastSyncSucceeded = diagnostics.lastSyncSucceeded
        snapshot.lastSyncErrorMessage = diagnostics.lastSyncErrorMessage
        snapshot.isSyncInFlight = diagnostics.isSyncInFlight

        guard Purchases.isConfigured else {
            snapshot.isConfigured = false
            snapshot.isAligned = false
            return snapshot
        }

        snapshot.isConfigured = true
        snapshot.rcAppUserID = Purchases.shared.appUserID
        snapshot.isAnonymous = Purchases.shared.isAnonymous
        snapshot.isAligned = AppServices.purchasesIdentity.isAligned(with: firebaseUserID)

        do {
            let info = try await Purchases.shared.customerInfo()
            snapshot.originalAppUserID = info.originalAppUserId
            snapshot.firstSeen = info.firstSeen
            snapshot.requestDate = info.requestDate
            snapshot.activeEntitlements = Self.join(info.entitlements.active.keys.sorted())
            snapshot.activeSubscriptions = Self.join(info.activeSubscriptions.sorted())
            snapshot.allPurchasedProducts = Self.join(info.allPurchasedProductIdentifiers.sorted())
        } catch {
            snapshot.customerInfoError = error.localizedDescription
        }

        do {
            let currencies = try await Purchases.shared.virtualCurrencies()
            snapshot.stampBalance = currencies[AppConfiguration.stampVirtualCurrencyCode]?.balance ?? 0
        } catch {
            snapshot.stampBalanceError = error.localizedDescription
        }

        return snapshot
    }

    private static func join(_ values: [String]) -> String? {
        values.isEmpty ? nil : values.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        PurchasesDebugView()
    }
}
