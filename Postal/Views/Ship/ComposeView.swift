//
//  ComposeView.swift
//  Postal
//
//  Created by Jack Kroll on 7/15/26.
//

import SwiftUI

struct ComposeView: View {
    @State var viewmodel: ViewModel
    @FocusState private var isComposerFocused: Bool

    init(viewmodel: ViewModel) {
        _viewmodel = State(initialValue: viewmodel)
    }

    var body: some View {
        // Keep letterText observation out of this body so the toolbar/nav chrome
        // does not rebuild on every keystroke — ComposeEditor owns that binding.
        ComposeEditor(viewmodel: viewmodel, isFocused: $isComposerFocused)
            .navigationTitle("Composer")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isComposerFocused = false
                    }
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                }
                ToolbarItem(placement: .bottomBar) {
                    ComposeSendButton(viewmodel: viewmodel)
                }
            }
    }
}

/// Isolated so TextEditor keystrokes only invalidate this subtree.
private struct ComposeEditor: View {
    @Bindable var viewmodel: ComposeView.ViewModel
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $viewmodel.letterText)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transaction { $0.animation = nil }

            HStack {
                Text(viewmodel.byteCountLabel)
                    .font(.caption)
                    .foregroundStyle(viewmodel.isOverByteLimit ? .red : .secondary)
                Spacer()
                if viewmodel.letterText.isEmpty {
                    Text("Required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.immediately)
    }
}

/// Isolated so send-button enablement can update without rebuilding the editor chrome.
private struct ComposeSendButton: View {
    @Bindable var viewmodel: ComposeView.ViewModel

    var body: some View {
        Button {
            Task { await viewmodel.send() }
        } label: {
            Label(viewmodel.isSending ? "Sending…" : "Send", systemImage: "paperplane.fill")
                .labelStyle(.titleAndIcon)
        }
        .disabled(!viewmodel.canSend)
    }
}

extension ComposeView {
    @Observable
    class ViewModel {
        let api: APIClient
        let limits: LetterLimits

        init(
            api: APIClient,
            source: MailboxSummary,
            destination: MailboxSummary,
            limits: LetterLimits = AppConfiguration.letterLimits
        ) {
            self.api = api
            self.source = source
            self.destination = destination
            self.limits = limits
        }

        var source: MailboxSummary
        var destination: MailboxSummary
        var letterText: String = ""
        var isSending = false
        var errorMessage: String? = nil
        var createdTrackingNumber: String? = nil
        var showSuccess: Bool = false

        var letterByteCount: Int {
            letterText.utf8.count
        }

        var isOverByteLimit: Bool {
            limits.exceedsLimit(letterByteCount, for: .text)
        }

        var canSend: Bool {
            !isSending
            && !trimmed(letterText).isEmpty
            && !isOverByteLimit
        }

        var byteCountLabel: String {
            limits.usageLabel(letterByteCount, for: .text)
        }

        private func trimmed(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func send() async {
            guard canSend
            else { return }

            isSending = true
            errorMessage = nil
            defer { isSending = false }

            let request = CreateShipmentRequest(
                origin: source,
                destination: destination,
                letter: .plain(trimmed(letterText))
            )

            do {
                let response = try await api.createShipment(request)
                createdTrackingNumber = response.trackingNumber
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }

    }
}


#Preview("Empty") {
    NavigationStack {
        ComposeView(viewmodel: .preview())
    }
}

#Preview("With Text") {
    NavigationStack {
        ComposeView(viewmodel: .preview(letterText: PreviewData.sampleLetterText))
    }
}

#Preview("Over Limit") {
    NavigationStack {
        ComposeView(viewmodel: .preview(
            letterText: String(repeating: "A", count: AppConfiguration.letterLimits.maxTextBytes + 1)
        ))
    }
}
