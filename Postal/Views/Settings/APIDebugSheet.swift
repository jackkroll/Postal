import SwiftUI
import UIKit

/// DEBUG sheet for inspecting Postal API limits, entitlements, and related `/api/me` payloads.
struct APIDebugSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot = APIDebugSnapshot.empty
    @State private var isRefreshing = false
    @State private var actionMessage: String?

    private let api: APIClient

    init(api: APIClient = AppServices.api) {
        self.api = api
    }

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                limitsSection
                entitlementsSection
                allowanceSection
                notificationEntitlementsSection
                preferencesSection
                mailboxesSection
                deviceTokensSection
                actionsSection

                if let actionMessage {
                    Section {
                        Text(actionMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("API Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Label("Close", systemImage: "xmark")
                        }
                    }
                }
            }
            .task { await refresh() }
            .refreshable { await refresh() }
        }
        .presentationDetents([.medium, .large])
    }

    private var connectionSection: some View {
        Section("Connection") {
            debugRow("API base URL", AppConfiguration.apiBaseURL.absoluteString)
            if let fetchedAt = snapshot.fetchedAt {
                LabeledContent("Fetched at", value: fetchedAt.formatted(date: .abbreviated, time: .standard))
            } else {
                LabeledContent("Fetched at", value: "—")
            }
        }
    }

    private var limitsSection: some View {
        Section {
            if let limits = snapshot.limits {
                LabeledContent("Plan ceilings", value: limits.planLabel)
                LabeledContent("is_subscriber", value: limits.isSubscriber ? "true" : "false")
                debugRow("text_max_bytes", formattedBytes(limits.maxTextBytes))
                debugRow("drawing_max_bytes", formattedBytes(limits.maxDrawingBytes))
                debugRow("text_max_bytes (raw)", "\(limits.maxTextBytes)")
                debugRow("drawing_max_bytes (raw)", "\(limits.maxDrawingBytes)")
            } else if let error = snapshot.limitsError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Letter Limits")
        } footer: {
            Text("GET /api/me/limits — ceilings used by compose.")
        }
    }

    private var entitlementsSection: some View {
        Section {
            if let entitlements = snapshot.entitlements {
                LabeledContent("is_subscriber", value: entitlements.isSubscriber ? "true" : "false")
                debugRow("expires_at", entitlements.expiresAt)
                LabeledContent("stamp_balance (API)", value: "\(entitlements.stampBalance)")
                LabeledContent("stamps_per_send", value: "\(entitlements.stampsPerSend)")
                LabeledContent("unlimited_sends", value: entitlements.unlimitedSends ? "true" : "false")
                LabeledContent("mailbox_limit", value: "\(entitlements.mailboxLimit)")
                LabeledContent("owned_mailboxes", value: "\(entitlements.ownedMailboxes)")
            } else if let error = snapshot.entitlementsError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Entitlements")
        } footer: {
            Text("GET /api/me/entitlements — stamp_balance may be overlaid from RevenueCat in the live app.")
        }
    }

    @ViewBuilder
    private var allowanceSection: some View {
        if let allowance = snapshot.entitlements?.allowance {
            Section("Stamp Allowance") {
                LabeledContent("amount", value: "\(allowance.amount)")
                LabeledContent("interval_seconds", value: "\(allowance.intervalSeconds)")
                LabeledContent("claimable", value: allowance.claimable ? "true" : "false")
                debugRow("last_claimed_at", allowance.lastClaimedAt)
                debugRow("next_claim_at", allowance.nextClaimAt)
                LabeledContent(
                    "available_while_subscribed",
                    value: allowance.availableWhileSubscribed ? "true" : "false"
                )
            }
        }
    }

    @ViewBuilder
    private var notificationEntitlementsSection: some View {
        if let notification = snapshot.entitlements?.notification {
            Section("Notification Entitlements") {
                debugRow("allowed_sent", notification.allowedSent.joined(separator: ", "))
                debugRow("allowed_inbound", notification.allowedInbound.joined(separator: ", "))
                debugRow("default_sent", notification.defaultSent)
                debugRow("default_inbound", notification.defaultInbound)
            }
        }
    }

    private var preferencesSection: some View {
        Section {
            if let preferences = snapshot.notificationPreferences {
                LabeledContent("sent", value: preferences.sent.rawValue)
                LabeledContent("inbound", value: preferences.inbound.rawValue)
                debugRow("effective_sent", preferences.effectiveSent?.rawValue)
                debugRow("effective_inbound", preferences.effectiveInbound?.rawValue)
                debugRow("allowed_sent", preferences.allowedSent.joined(separator: ", "))
                debugRow("allowed_inbound", preferences.allowedInbound.joined(separator: ", "))
                debugRow("updated_at", preferences.updatedAt)
            } else if let error = snapshot.notificationPreferencesError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Notification Preferences")
        } footer: {
            Text("GET /api/me/notification-preferences")
        }
    }

    private var mailboxesSection: some View {
        Section {
            if let mailboxes = snapshot.mailboxes {
                if mailboxes.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mailboxes) { mailbox in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mailbox.label)
                            Text("\(mailbox.id.rawValue) · PO \(mailbox.postOfficeID)")
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            } else if let error = snapshot.mailboxesError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Mailboxes")
        } footer: {
            Text("GET /api/me/mailboxes")
        }
    }

    private var deviceTokensSection: some View {
        Section {
            if let tokens = snapshot.deviceTokens {
                if tokens.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(token.platform)
                            Text(token.token)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(2)
                            if let appInstanceID = token.appInstanceID {
                                Text("instance: \(appInstanceID)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                            }
                            Text(token.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } else if let error = snapshot.deviceTokensError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Device Tokens")
        } footer: {
            Text("GET /api/me/device-tokens")
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
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .disabled(isRefreshing)

            Button {
                copySnapshot()
            } label: {
                Label("Copy Snapshot", systemImage: "doc.on.doc")
            }
            .disabled(isRefreshing)
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

    private func formattedBytes(_ bytes: Int) -> String {
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
        return "\(formatted) (\(bytes))"
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        snapshot = await APIDebugSnapshot.capture(api: api)
    }

    private func copySnapshot() {
        UIPasteboard.general.string = snapshot.copyText
        actionMessage = "Copied API debug snapshot."
    }
}

struct APIDebugSnapshot: Sendable {
    var fetchedAt: Date?
    var limits: LetterLimits?
    var limitsError: String?
    var entitlements: UserEntitlements?
    var entitlementsError: String?
    var notificationPreferences: NotificationPreferencesSummary?
    var notificationPreferencesError: String?
    var mailboxes: [MailboxSummary]?
    var mailboxesError: String?
    var deviceTokens: [DeviceTokenSummary]?
    var deviceTokensError: String?

    static let empty = APIDebugSnapshot()

    var copyText: String {
        var lines: [String] = [
            "API base URL: \(AppConfiguration.apiBaseURL.absoluteString)",
            "Fetched at: \(fetchedAt?.description ?? "—")",
            "",
        ]

        if let limits {
            lines += [
                "Letter Limits:",
                "  is_subscriber: \(limits.isSubscriber)",
                "  text_max_bytes: \(limits.maxTextBytes)",
                "  drawing_max_bytes: \(limits.maxDrawingBytes)",
                "",
            ]
        } else {
            lines += ["Letter Limits: \(limitsError ?? "—")", ""]
        }

        if let entitlements {
            lines += [
                "Entitlements:",
                "  is_subscriber: \(entitlements.isSubscriber)",
                "  expires_at: \(entitlements.expiresAt ?? "—")",
                "  stamp_balance: \(entitlements.stampBalance)",
                "  stamps_per_send: \(entitlements.stampsPerSend)",
                "  unlimited_sends: \(entitlements.unlimitedSends)",
                "  mailbox_limit: \(entitlements.mailboxLimit)",
                "  owned_mailboxes: \(entitlements.ownedMailboxes)",
                "  allowance.amount: \(entitlements.allowance.amount)",
                "  allowance.claimable: \(entitlements.allowance.claimable)",
                "  allowance.next_claim_at: \(entitlements.allowance.nextClaimAt ?? "—")",
                "",
            ]
        } else {
            lines += ["Entitlements: \(entitlementsError ?? "—")", ""]
        }

        if let preferences = notificationPreferences {
            lines += [
                "Notification Preferences:",
                "  sent: \(preferences.sent.rawValue)",
                "  inbound: \(preferences.inbound.rawValue)",
                "  effective_sent: \(preferences.effectiveSent?.rawValue ?? "—")",
                "  effective_inbound: \(preferences.effectiveInbound?.rawValue ?? "—")",
                "",
            ]
        }

        if let mailboxes {
            lines.append("Mailboxes (\(mailboxes.count)):")
            for mailbox in mailboxes {
                lines.append("  \(mailbox.label) — \(mailbox.id.rawValue) PO \(mailbox.postOfficeID)")
            }
            lines.append("")
        }

        if let deviceTokens {
            lines.append("Device Tokens (\(deviceTokens.count)):")
            for token in deviceTokens {
                lines.append("  \(token.platform): \(token.token)")
            }
        }

        return lines.joined(separator: "\n")
    }

    @MainActor
    static func capture(api: APIClient) async -> APIDebugSnapshot {
        var snapshot = APIDebugSnapshot.empty
        snapshot.fetchedAt = Date()

        async let limitsResult: Result<LetterLimits, Error> = {
            do { return .success(try await api.getLimits()) }
            catch { return .failure(error) }
        }()
        async let entitlementsResult: Result<UserEntitlements, Error> = {
            do { return .success(try await api.getEntitlements()) }
            catch { return .failure(error) }
        }()
        async let preferencesResult: Result<NotificationPreferencesSummary, Error> = {
            do { return .success(try await api.getNotificationPreferences()) }
            catch { return .failure(error) }
        }()
        async let mailboxesResult: Result<[MailboxSummary], Error> = {
            do { return .success(try await api.listOwnedMailboxes()) }
            catch { return .failure(error) }
        }()
        async let tokensResult: Result<[DeviceTokenSummary], Error> = {
            do { return .success(try await api.listDeviceTokens()) }
            catch { return .failure(error) }
        }()

        switch await limitsResult {
        case .success(let limits):
            snapshot.limits = limits
        case .failure(let error):
            snapshot.limitsError = error.localizedDescription
        }

        switch await entitlementsResult {
        case .success(let entitlements):
            snapshot.entitlements = entitlements
        case .failure(let error):
            snapshot.entitlementsError = error.localizedDescription
        }

        switch await preferencesResult {
        case .success(let preferences):
            snapshot.notificationPreferences = preferences
        case .failure(let error):
            snapshot.notificationPreferencesError = error.localizedDescription
        }

        switch await mailboxesResult {
        case .success(let mailboxes):
            snapshot.mailboxes = mailboxes
        case .failure(let error):
            snapshot.mailboxesError = error.localizedDescription
        }

        switch await tokensResult {
        case .success(let tokens):
            snapshot.deviceTokens = tokens
        case .failure(let error):
            snapshot.deviceTokensError = error.localizedDescription
        }

        return snapshot
    }
}

#Preview {
    APIDebugSheet()
}
