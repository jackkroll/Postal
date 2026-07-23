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

    private var isSelecting: Bool { onSelect != nil }

    var body: some View {
        Group {
            if viewmodel.addresses.isEmpty {
                ContentUnavailableView {
                    Label("No Addresses Saved", systemImage: "house.fill")
                } description: {
                    Text(
                        isSelecting
                            ? "Add a nickname and mailbox, then choose it as the destination."
                            : "Add a nickname and mailbox so you can send letters faster."
                    )
                } actions: {
                    Button("Add Address") {
                        viewmodel.presentAdd()
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewmodel.addresses) { address in
                            SingleAddressEntryView(
                                address: address,
                                selectedEdit: $viewmodel.editor,
                                onSelect: onSelect
                            )
                        }
                    }
                    .padding()
                }
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

struct SingleAddressEntryView: View {
    let address: AddressBookEntrySummary
    @Binding var selectedEdit: AddressEditorMode?
    var onSelect: ((AddressBookEntrySummary) -> Void)? = nil

    private var isSelecting: Bool { onSelect != nil }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(address.nickname)
                        .font(.title3)
                        .bold()
                        HStack {
                            Text(address.mailboxSummary.locationLabel)
                            Text(address.mailboxID.code)
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)

            if let notes = address.notes {
                Text(notes)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if isSelecting {
                    Button {
                        onSelect?(address)
                    } label: {
                        Label("Select", systemImage: "checkmark.circle.fill")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.green)
                            .tint(.primary)
                            .clipShape(Capsule())
                    }
                } else {
                    NavigationLink(value: ViewRoute.ship(destination: address.mailboxSummary)) {
                        Label("Send Letter", systemImage: "envelope.fill")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.green)
                            .tint(.primary)
                            .clipShape(Capsule())
                    }
                }
                Button {
                    withAnimation {
                        selectedEdit = .edit(address)
                    }
                } label: {
                    Label("Edit Address", systemImage: "pencil")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.blue)
                        .tint(.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension AddressBook {
    @Observable
    class ViewModel {
        let api: APIClient
        var addresses: [AddressBookEntrySummary]
        var errorMsg: String?
        var editor: AddressEditorMode?

        init(api: APIClient) {
            self.api = api
            self.addresses = []
            Task {
                await fetchAddresses()
            }
        }

        func presentAdd() {
            editor = .add
        }

        func fetchAddresses() async {
            do {
                addresses = try await api.listAddressBook()
            } catch {
                errorMsg = "Failed to fetch address book"
            }
        }

        func applyUpdate(_ entry: AddressBookEntrySummary) {
            if let index = addresses.firstIndex(where: { $0.id == entry.id }) {
                addresses[index] = entry
            } else {
                addresses.insert(entry, at: 0)
            }
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        AddressBook(viewmodel: .preview(addresses: []))
    }
}

#Preview("Populated") {
    NavigationStack {
        AddressBook(viewmodel: .preview())
    }
}

#Preview("Selection") {
    NavigationStack {
        AddressBook(viewmodel: .preview()) { _ in }
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
