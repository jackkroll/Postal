//
//  AddressBook.swift
//  Postal
//
//  Created by Jack Kroll on 7/19/26.
//

import Foundation
import SwiftUI

struct AddressBook: View {
    @State var viewmodel: ViewModel
    /// When set, the book is used to pick an address (no browse-only actions like Send Letter).
    var onSelect: ((AddressBookEntrySummary) -> Void)? = nil
    private let loadsOnAppear: Bool

    private var isSelecting: Bool { onSelect != nil }

    init(
        viewmodel: ViewModel,
        loadsOnAppear: Bool = true,
        onSelect: ((AddressBookEntrySummary) -> Void)? = nil
    ) {
        _viewmodel = State(initialValue: viewmodel)
        self.loadsOnAppear = loadsOnAppear
        self.onSelect = onSelect
    }

    var body: some View {
        Group {
            if let onSelect {
                AddressBookSelectionList(viewmodel: viewmodel, onSelect: onSelect)
            } else {
                AddressBookBrowseList(viewmodel: viewmodel)
            }
        }
        .navigationTitle(isSelecting ? "Choose Address" : "Address Book")
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarSpacer(placement: .bottomBar)
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    viewmodel.presentAdd()
                } label: {
                    Label("Add Address", systemImage: "plus")
                }
            }
            if !isSelecting {
                ToolbarItem(placement: .bottomBar) {
                    NavigationLink(value: ViewRoute.claimBox) {
                        Label(
                            viewmodel.ownedMailboxes.isEmpty ? "Claim Mailbox" : "Claim Another",
                            systemImage: "tray.and.arrow.down"
                        )
                    }
                }
            }
        }
        .sheet(item: $viewmodel.editor) { editor in
            NavigationStack {
                AddressEditView(
                    mode: editor,
                    api: viewmodel.api,
                    onSaved: { saved in
                        viewmodel.applyUpdate(saved)
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            guard loadsOnAppear else { return }
            await viewmodel.refresh()
        }
    }
}

struct AddressBookBrowseList: View {
    var viewmodel: AddressBook.ViewModel

    var body: some View {
        List {
            MyMailboxesSection(viewmodel: viewmodel)
            SavedAddressesSection(viewmodel: viewmodel, allowsDelete: true)
        }
    }
}

struct AddressBookSelectionList: View {
    var viewmodel: AddressBook.ViewModel
    var onSelect: (AddressBookEntrySummary) -> Void

    var body: some View {
        if viewmodel.addresses.isEmpty {
            ContentUnavailableView {
                Label("No Addresses Saved", systemImage: "house.fill")
            } description: {
                Text("Add a nickname and mailbox, then choose it as the destination.")
            } actions: {
                Button("Add Address") {
                    viewmodel.presentAdd()
                }
            }
        } else {
            List {
                SavedAddressesSection(
                    viewmodel: viewmodel,
                    allowsDelete: true,
                    onSelect: onSelect
                )
            }
        }
    }
}

struct MyMailboxesSection: View {
    var viewmodel: AddressBook.ViewModel

    var body: some View {
        Section {
            if viewmodel.isLoadingOwned, viewmodel.ownedMailboxes.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading your mailboxes…")
                        .foregroundStyle(.secondary)
                }
            } else if viewmodel.ownedMailboxes.isEmpty {
                ContentUnavailableView {
                    Label("No Mailboxes", systemImage: "tray")
                } description: {
                    Text("Claim a mailbox to send and receive letters.")
                } actions: {
                    NavigationLink(value: ViewRoute.claimBox) {
                        Text("Claim a Mailbox")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(viewmodel.ownedMailboxes) { mailbox in
                    NavigationLink(value: ViewRoute.ship(origin: mailbox)) {
                        OwnedMailboxRowView(mailbox: mailbox)
                    }
                }
            }
        } header: {
            Text("My Mailboxes")
        }
    }
}

struct SavedAddressesSection: View {
    var viewmodel: AddressBook.ViewModel
    var allowsDelete: Bool = true
    var onSelect: ((AddressBookEntrySummary) -> Void)? = nil

    var body: some View {
        Section {
            if viewmodel.addresses.isEmpty {
                SavedAddressesEmptyContent(
                    isSelecting: onSelect != nil,
                    onAdd: { viewmodel.presentAdd() }
                )
            } else {
                SavedAddressesRows(
                    addresses: viewmodel.addresses,
                    allowsDelete: allowsDelete,
                    onSelect: onSelect,
                    onEdit: { address in
                        viewmodel.editor = .edit(address)
                    },
                    onDelete: { offsets in
                        viewmodel.deleteAddresses(at: offsets)
                    }
                )
            }
        } header: {
            Text("Saved Addresses")
        } footer: {
            if viewmodel.addresses.isEmpty {
                EmptyView()
            } else {
                Text("Swipe left to delete, or right to edit.")
            }
        }
    }
}

struct SavedAddressesEmptyContent: View {
    let isSelecting: Bool
    let onAdd: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Addresses Saved", systemImage: "house.fill")
        } description: {
            Text(
                isSelecting
                    ? "Add a nickname and mailbox, then choose it as the destination."
                    : "Add a nickname and mailbox so you can send letters faster."
            )
        } actions: {
            Button("Add Address", action: onAdd)
        }
    }
}

struct SavedAddressesRows: View {
    let addresses: [AddressBookEntrySummary]
    var allowsDelete: Bool
    var onSelect: ((AddressBookEntrySummary) -> Void)?
    var onEdit: (AddressBookEntrySummary) -> Void
    var onDelete: (IndexSet) -> Void

    var body: some View {
        ForEach(addresses) { address in
            SavedAddressRow(address: address, onSelect: onSelect)
                .swipeActions(edge: .leading) {
                    Button {
                        onEdit(address)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
        }
        .onDelete(perform: allowsDelete ? onDelete : { _ in })
    }
}

struct SavedAddressRow: View {
    let address: AddressBookEntrySummary
    var onSelect: ((AddressBookEntrySummary) -> Void)? = nil

    var body: some View {
        Group {
            if let onSelect {
                Button {
                    onSelect(address)
                } label: {
                    AddressBookRowView(address: address)
                }
                .foregroundStyle(.primary)
            } else {
                NavigationLink(value: ViewRoute.ship(destination: address.mailboxSummary)) {
                    AddressBookRowView(address: address)
                }
            }
        }
    }
}

enum AddressEditorMode: Identifiable, Hashable {
    case add
    case edit(AddressBookEntrySummary)

    var id: String {
        switch self {
        case .add:
            return "add"
        case let .edit(entry):
            return entry.id
        }
    }

    var navigationTitle: String {
        switch self {
        case .add: "New Address"
        case .edit: "Edit Address"
        }
    }
}

struct AddressEditView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: AddressEditorMode
    let api: APIClient
    var onSaved: ((AddressBookEntrySummary) -> Void)?

    @State private var nickname: String
    @State private var notes: String
    @State private var selectedMailbox: MailboxSummary?
    @State private var isMailboxPickerPresented = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        mode: AddressEditorMode,
        api: APIClient,
        onSaved: ((AddressBookEntrySummary) -> Void)? = nil
    ) {
        self.mode = mode
        self.api = api
        self.onSaved = onSaved

        switch mode {
        case .add:
            self._nickname = State(initialValue: "")
            self._notes = State(initialValue: "")
            self._selectedMailbox = State(initialValue: nil)
        case let .edit(entry):
            self._nickname = State(initialValue: entry.nickname)
            self._notes = State(initialValue: entry.notes ?? "")
            self._selectedMailbox = State(initialValue: entry.mailboxSummary)
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Nickname", text: $nickname)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button {
                    isMailboxPickerPresented = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let selectedMailbox {
                                Text(selectedMailbox.label)
                                    .foregroundStyle(.primary)
                                Text(selectedMailbox.locationLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(selectedMailbox.id.code)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Select mailbox")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Mailbox")
            } footer: {
                Text("Search for a post office, then enter the mailbox code.")
            }
            .tint(.primary)

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if #available(iOS 26.0, *) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                    .disabled(isSaving)
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .disabled(isSaving)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if #available(iOS 26.0, *) {
                    Button(role: .confirm) {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                } else {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Done", systemImage: "checkmark")
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $isMailboxPickerPresented) {
            // Nested mailbox lookup only — no Address Book shortcut while already picking.
            DestinationMailboxPickerSheet(
                api: api,
                title: "Choose Mailbox",
                showsAddressBookShortcut: false
            ) { mailbox in
                selectedMailbox = mailbox
                errorMessage = nil
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedMailbox != nil
            && !isSaving
    }

    private func save() async {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty, let selectedMailbox else { return }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let saved: AddressBookEntrySummary
            switch mode {
            case .add:
                saved = try await api.createAddressBookEntry(
                    nickname: trimmedNickname,
                    mailboxID: selectedMailbox.id,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                )
            case let .edit(entry):
                saved = try await api.updateAddressBookEntry(
                    id: entry.id,
                    nickname: trimmedNickname,
                    mailboxID: selectedMailbox.id,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                )
            }
            onSaved?(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct OwnedMailboxRowView: View {
    let mailbox: MailboxSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mailbox.label)
                .font(.body.weight(.semibold))
            HStack(spacing: 6) {
                Text(mailbox.locationLabel)
                Text(mailbox.id.code)
                    .font(.caption.monospaced())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct AddressBookRowView: View {
    let address: AddressBookEntrySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(address.nickname)
                .font(.body.weight(.semibold))
            HStack(spacing: 6) {
                Text(address.mailboxSummary.locationLabel)
                Text(address.mailboxID.code)
                    .font(.caption.monospaced())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let notes = address.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

extension AddressBook {
    @Observable
    class ViewModel {
        let api: APIClient
        var addresses: [AddressBookEntrySummary]
        var ownedMailboxes: [MailboxSummary]
        var isLoadingOwned = false
        var errorMsg: String?
        var editor: AddressEditorMode?

        init(api: APIClient) {
            self.api = api
            self.addresses = []
            self.ownedMailboxes = []
        }

        func presentAdd() {
            editor = .add
        }

        func refresh() async {
            async let addressesFetch: Void = fetchAddresses()
            async let ownedFetch: Void = fetchOwnedMailboxes()
            _ = await (addressesFetch, ownedFetch)
        }

        func fetchAddresses() async {
            do {
                addresses = try await api.listAddressBook()
            } catch {
                errorMsg = "Failed to fetch address book"
            }
        }

        func fetchOwnedMailboxes() async {
            isLoadingOwned = true
            defer { isLoadingOwned = false }
            do {
                ownedMailboxes = try await api.listOwnedMailboxes()
            } catch {
                errorMsg = "Failed to fetch mailboxes"
            }
        }

        func applyUpdate(_ entry: AddressBookEntrySummary) {
            if let index = addresses.firstIndex(where: { $0.id == entry.id }) {
                addresses[index] = entry
            } else {
                addresses.insert(entry, at: 0)
            }
        }

        func deleteAddresses(at offsets: IndexSet) {
            let entries = offsets.compactMap { index -> AddressBookEntrySummary? in
                guard addresses.indices.contains(index) else { return nil }
                return addresses[index]
            }
            addresses.remove(atOffsets: offsets)
            Task {
                for entry in entries {
                    do {
                        try await api.deleteAddressBookEntry(id: entry.id)
                    } catch {
                        errorMsg = "Failed to delete address"
                        await fetchAddresses()
                        return
                    }
                }
            }
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        AddressBook(viewmodel: .preview(addresses: [], ownedMailboxes: []), loadsOnAppear: false)
    }
}

#Preview("Populated") {
    NavigationStack {
        AddressBook(viewmodel: .preview(), loadsOnAppear: false)
    }
}

#Preview("Mailboxes Only") {
    NavigationStack {
        AddressBook(viewmodel: .preview(addresses: []), loadsOnAppear: false)
    }
}

#Preview("Selection") {
    NavigationStack {
        AddressBook(viewmodel: .preview(), loadsOnAppear: false) { _ in }
    }
}

#Preview("Add") {
    NavigationStack {
        AddressEditView(mode: .add, api: APIClient())
    }
}

#Preview("Edit") {
    NavigationStack {
        AddressEditView(
            mode: .edit(PreviewData.addressBookEntries[0]),
            api: APIClient()
        )
    }
}
