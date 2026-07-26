import SwiftUI

/// Full-page writing surface — the text counterpart to `CanvasView`.
///
/// Owns the edited text so keystrokes stay off the letter creation stage; changes
/// are reported upward on a debounce for autosave.
struct LetterTextComposerView: View {
    @Binding var draftSaveStatus: DraftSaveStatus
    let limits: LetterLimits
    let onTextChange: (String) -> Void
    let onContinue: (String) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var text: String
    @State private var changeNotifyTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    init(
        initialText: String = "",
        draftSaveStatus: Binding<DraftSaveStatus> = .constant(.hidden),
        limits: LetterLimits = AppConfiguration.letterLimits,
        onTextChange: @escaping (String) -> Void = { _ in },
        onContinue: @escaping (String) -> Void
    ) {
        _text = State(initialValue: initialText)
        _draftSaveStatus = draftSaveStatus
        self.limits = limits
        self.onTextChange = onTextChange
        self.onContinue = onContinue
    }

    private var byteCount: Int { text.utf8.count }
    private var isOverLimit: Bool { limits.exceedsLimit(byteCount, for: .text) }
    private var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            LetterComposerStatusBar(
                draftSaveStatus: $draftSaveStatus,
                byteCount: byteCount,
                kind: .text,
                limits: limits
            )

            TextEditor(text: $text)
                .focused($isFocused)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transaction { $0.animation = nil }
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Write your letter…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 20)
                            .padding(.leading, 21)
                            .allowsHitTesting(false)
                    }
                }
        }
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Write Letter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isFocused = false }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    text = ""
                    notifyTextChange(immediate: true)
                } label: {
                    Label("Clear", systemImage: "trash.fill")
                        .labelStyle(.iconOnly)
                }
                .disabled(text.isEmpty)
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    isFocused = false
                    notifyTextChange(immediate: true)
                    onContinue(text)
                } label: {
                    Label("Continue", systemImage: "chevron.forward")
                }
                .disabled(isBlank || isOverLimit)
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            isFocused = true
        }
        .onChange(of: text) { _, _ in
            scheduleTextChangeNotification()
        }
        .onDisappear {
            notifyTextChange(immediate: true)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                notifyTextChange(immediate: true)
            }
        }
    }

    private func scheduleTextChangeNotification() {
        changeNotifyTask?.cancel()
        changeNotifyTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            notifyTextChange(immediate: true)
        }
    }

    private func notifyTextChange(immediate: Bool) {
        if immediate {
            changeNotifyTask?.cancel()
        }
        onTextChange(text)
    }
}

#Preview("Empty") {
    NavigationStack {
        LetterTextComposerView(draftSaveStatus: .constant(.saved)) { _ in }
    }
}

#Preview("Over Limit") {
    NavigationStack {
        LetterTextComposerView(
            initialText: String(repeating: "A", count: AppConfiguration.letterLimits.maxTextBytes + 1),
            draftSaveStatus: .constant(.saved)
        ) { _ in }
    }
}
