import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage(AppStorageKeys.showInboundLetters) private var showInboundLetters = true
    @Environment(\.dismiss) private var dismiss
    @State var viewmodel: ViewModel
    @State private var isDeleteAccountPresented = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: viewmodel.statusTitle)

                if let registeredToken = viewmodel.registeredTokenPreview {
                    LabeledContent("Device Token") {
                        Text(registeredToken)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if viewmodel.isRegistered {
                    Button(role: .destructive) {
                        Task { await viewmodel.disableNotifications() }
                    } label: {
                        if viewmodel.isDisabling {
                            HStack {
                                ProgressView()
                                Text("Disabling…")
                            }
                        } else {
                            Label("Disable Notifications", systemImage: "bell.slash")
                        }
                    }
                    .disabled(!viewmodel.canDisableNotifications)
                } else {
                    Button {
                        Task { await viewmodel.enableNotifications() }
                    } label: {
                        if viewmodel.isRegistering {
                            HStack {
                                ProgressView()
                                Text("Enabling…")
                            }
                        } else {
                            Label(
                                viewmodel.enableButtonTitle,
                                systemImage: "bell.badge"
                            )
                        }
                    }
                    .disabled(!viewmodel.canEnableNotifications)
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text(viewmodel.footerText)
            }

            Section {
                Picker("Sent letters", selection: $viewmodel.sentMode) {
                    ForEach(SentNotificationMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .disabled(viewmodel.isLoadingPreferences || viewmodel.isSavingPreferences)

                Picker("Inbound letters", selection: $viewmodel.inboundMode) {
                    ForEach(InboundNotificationMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .disabled(viewmodel.isLoadingPreferences || viewmodel.isSavingPreferences)

                if viewmodel.isSavingPreferences {
                    HStack {
                        ProgressView()
                        Text("Saving…")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Notification Preferences")
            } footer: {
                Text(viewmodel.preferencesFooterText)
            }
            .onChange(of: viewmodel.sentMode) { _, _ in
                Task { await viewmodel.savePreferencesIfNeeded() }
            }
            .onChange(of: viewmodel.inboundMode) { _, _ in
                Task { await viewmodel.savePreferencesIfNeeded() }
            }

            Section {
                Toggle("Show inbound letters", isOn: $showInboundLetters)
            } header: {
                Text("Letters Display")
            } footer: {
                Text("When enabled, an Inbound tab appears on the letters page for mail arriving at your boxes.")
            }

            if let errorMessage = viewmodel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if viewmodel.showSuccess {
                Section {
                    Text("This device is registered for shipment updates.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button(role: .destructive) {
                    Task {
                        await viewmodel.signOut()
                        dismiss()
                    }
                } label: {
                    Label("Sign Out", systemImage: "person.crop.circle")
                }

                Button(role: .destructive) {
                    isDeleteAccountPresented = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
                .disabled(viewmodel.isDeletingAccount)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewmodel.refresh()
        }
        .sheet(isPresented: $isDeleteAccountPresented) {
            DeleteAccountConfirmationSheet(viewmodel: viewmodel) {
                dismiss()
            }
        }
    }
}

private struct DeleteAccountConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewmodel: SettingsView.ViewModel
    @State private var confirmationText = ""
    var onDeleted: () -> Void

    private var canConfirm: Bool {
        confirmationText == SettingsView.ViewModel.accountDeletionConfirmationPhrase
            && !viewmodel.isDeletingAccount
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "This permanently deletes your Postal account, releases your mailboxes, and removes associated data. This cannot be undone."
                    )
                    .foregroundStyle(.secondary)
                }

                Section {
                    TextField("Type delete to confirm", text: $confirmationText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(viewmodel.isDeletingAccount)
                } footer: {
                    Text("Type “delete” exactly to enable deletion.")
                }

                if let errorMessage = viewmodel.deleteAccountErrorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            let didDelete = await viewmodel.deleteAccount()
                            guard didDelete else { return }
                            dismiss()
                            onDeleted()
                        }
                    } label: {
                        if viewmodel.isDeletingAccount {
                            HStack {
                                ProgressView()
                                Text("Deleting…")
                            }
                        } else {
                            Text("Delete Account")
                        }
                    }
                    .disabled(!canConfirm)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) { dismiss() }
                            .disabled(viewmodel.isDeletingAccount)
                    } else {
                        Button("Cancel") { dismiss() }
                            .disabled(viewmodel.isDeletingAccount)
                    }
                }
            }
            .interactiveDismissDisabled(viewmodel.isDeletingAccount)
            .onAppear {
                confirmationText = ""
                viewmodel.deleteAccountErrorMessage = nil
            }
        }
        .presentationDetents([.medium])
    }
}

extension SettingsView {
    @Observable
    class ViewModel {
        let api: APIClient
        let auth: AuthProviding
        let push: PushNotificationsProviding

        var authorizationStatus: UNAuthorizationStatus = .notDetermined
        var registeredSummary: DeviceTokenSummary?
        var isRegistering = false
        var isDisabling = false
        var errorMessage: String?
        var showSuccess = false

        var sentMode: SentNotificationMode = .shipmentDetails
        var inboundMode: InboundNotificationMode = .shipmentDetails
        var isLoadingPreferences = false
        var isSavingPreferences = false
        var isDeletingAccount = false
        var deleteAccountErrorMessage: String?

        static let accountDeletionConfirmationPhrase = "delete"

        private var lastSavedSent: SentNotificationMode?
        private var lastSavedInbound: InboundNotificationMode?

        init(api: APIClient, auth: AuthProviding, push: PushNotificationsProviding) {
            self.api = api
            self.auth = auth
            self.push = push
        }

        var isRegistered: Bool {
            registeredSummary != nil
        }

        var canEnableNotifications: Bool {
            !isRegistering && !isDisabling && authorizationStatus != .denied
        }

        var canDisableNotifications: Bool {
            isRegistered && !isRegistering && !isDisabling
        }

        var enableButtonTitle: String {
            switch authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return "Register This Device"
            default:
                return "Enable Notifications"
            }
        }

        var statusTitle: String {
            if isRegistered {
                return "Registered"
            }
            switch authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return "Allowed"
            case .denied:
                return "Denied"
            case .notDetermined:
                return "Off"
            @unknown default:
                return "Unknown"
            }
        }

        var footerText: String {
            if authorizationStatus == .denied {
                return "Notifications are off for Postal. Enable them in iOS Settings, then come back here."
            }
            if isRegistered {
                return "This device receives shipment updates. Disable to stop notifications here."
            }
            return "Get notified when your shipments move. Postal will ask for permission, then register this device with the server."
        }

        var preferencesFooterText: String {
            "\(sentMode.footer) \(inboundMode.footer)"
        }

        var registeredTokenPreview: String? {
            registeredSummary?.token
        }

        @MainActor
        func refresh() async {
            await push.refreshAuthorizationStatus()
            authorizationStatus = push.authorizationStatus
            errorMessage = nil

            await refreshPreferences()

            do {
                let tokens = try await api.listDeviceTokens()
                if let deviceToken = push.currentDeviceToken {
                    registeredSummary = tokens.first(where: { $0.token == deviceToken })
                } else {
                    registeredSummary = nil
                }
                showSuccess = registeredSummary != nil
            } catch {
                // Listing is best-effort; registration can still succeed.
            }
        }

        @MainActor
        func refreshPreferences() async {
            isLoadingPreferences = true
            defer { isLoadingPreferences = false }

            do {
                let preferences = try await api.getNotificationPreferences()
                sentMode = preferences.sent
                inboundMode = preferences.inbound
                lastSavedSent = preferences.sent
                lastSavedInbound = preferences.inbound
            } catch {
                // Preferences are optional until the device is signed in with a working API.
            }
        }

        @MainActor
        func savePreferencesIfNeeded() async {
            guard !isLoadingPreferences, !isSavingPreferences else { return }
            guard sentMode != lastSavedSent || inboundMode != lastSavedInbound else { return }

            isSavingPreferences = true
            errorMessage = nil
            defer { isSavingPreferences = false }

            do {
                let preferences = try await api.updateNotificationPreferences(
                    sent: sentMode,
                    inbound: inboundMode
                )
                sentMode = preferences.sent
                inboundMode = preferences.inbound
                lastSavedSent = preferences.sent
                lastSavedInbound = preferences.inbound
            } catch {
                errorMessage = error.localizedDescription
                if let lastSavedSent {
                    sentMode = lastSavedSent
                }
                if let lastSavedInbound {
                    inboundMode = lastSavedInbound
                }
            }
        }

        @MainActor
        func enableNotifications() async {
            isRegistering = true
            errorMessage = nil
            showSuccess = false
            defer { isRegistering = false }

            do {
                let token = try await push.requestAuthorizationAndToken()
                authorizationStatus = push.authorizationStatus

                let summary = try await api.registerDeviceToken(
                    token,
                    platform: .ios,
                    appInstanceID: push.appInstanceID
                )
                registeredSummary = summary
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                authorizationStatus = push.authorizationStatus
            }
        }

        @MainActor
        func disableNotifications() async {
            isDisabling = true
            errorMessage = nil
            defer { isDisabling = false }

            do {
                let token = push.currentDeviceToken ?? registeredSummary?.token
                if let token {
                    try await api.unregisterDeviceToken(token)
                }
                push.clearLocalRegistration(userOptedOut: true)
                registeredSummary = nil
                showSuccess = false
                await push.refreshAuthorizationStatus()
                authorizationStatus = push.authorizationStatus
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        /// Unregisters this device for push while still authenticated, then signs out.
        @MainActor
        func signOut() async {
            if let token = push.currentDeviceToken {
                try? await api.unregisterDeviceToken(token)
            }
            push.clearLocalRegistration(userOptedOut: false)
            registeredSummary = nil
            showSuccess = false
            try? auth.signOut()
        }

        /// Deletes the account via `DELETE /api/me`, then clears local auth/push state.
        @MainActor
        @discardableResult
        func deleteAccount() async -> Bool {
            isDeletingAccount = true
            deleteAccountErrorMessage = nil
            defer { isDeletingAccount = false }

            do {
                try await api.deleteMyAccount()
                push.clearLocalRegistration(userOptedOut: false)
                registeredSummary = nil
                showSuccess = false
                try? auth.signOut()
                return true
            } catch {
                deleteAccountErrorMessage = error.localizedDescription
                return false
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewmodel: .preview())
    }
}
