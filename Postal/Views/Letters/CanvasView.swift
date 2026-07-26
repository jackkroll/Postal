//
//  CanvasView.swift
//  Postal
//
//  Created by Jack Kroll on 7/21/26.
//

import SwiftUI
import PencilKit

struct CanvasView: View {
    let initialDrawingData: Data?
    @Binding var draftSaveStatus: DraftSaveStatus
    let limits: LetterLimits
    let onDrawingChange: (Data) -> Void
    let onContinue: (Data) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var canvas = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var isDrawingEmpty = true
    @State private var isToolPickerVisible = true
    @State private var didRestoreInitialDrawing = false
    @State private var drawingByteCount = 0
    @State private var changeNotifyTask: Task<Void, Never>?

    init(
        initialDrawingData: Data? = nil,
        draftSaveStatus: Binding<DraftSaveStatus> = .constant(.hidden),
        limits: LetterLimits = AppConfiguration.letterLimits,
        onDrawingChange: @escaping (Data) -> Void = { _ in },
        onContinue: @escaping (Data) -> Void
    ) {
        self.initialDrawingData = initialDrawingData
        _draftSaveStatus = draftSaveStatus
        self.limits = limits
        self.onDrawingChange = onDrawingChange
        self.onContinue = onContinue
    }

    private var isOverLimit: Bool { limits.exceedsLimit(drawingByteCount, for: .drawing) }

    var body: some View {
        VStack(spacing: 0) {
            LetterComposerStatusBar(
                draftSaveStatus: $draftSaveStatus,
                byteCount: drawingByteCount,
                kind: .drawing,
                limits: limits
            )

            CanvasUIView(
                canvasView: $canvas,
                toolPicker: $toolPicker,
                isDrawingEmpty: $isDrawingEmpty,
                onDrawingChange: scheduleDrawingChangeNotification
            )
            .background(Color(.systemBackground))
        }
        .navigationTitle("Draw Letter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isToolPickerVisible.toggle()
                    toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvas)
                    canvas.becomeFirstResponder()
                } label: {
                    Label(isToolPickerVisible ? "Hide Tools" : "Show Tools", systemImage: isToolPickerVisible ? "pencil.slash" : "pencil")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    canvas.drawing = PKDrawing()
                    isDrawingEmpty = true
                    notifyDrawingChange(immediate: true)
                } label: {
                    Label("Clear", systemImage: "trash.fill")
                        .labelStyle(.iconOnly)
                }
                .disabled(isDrawingEmpty)
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    notifyDrawingChange(immediate: true)
                    onContinue(canvas.drawing.dataRepresentation())
                } label: {
                    Label("Continue", systemImage: "chevron.forward")
                }
                .disabled(isDrawingEmpty || isOverLimit)
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            restoreInitialDrawingIfNeeded()
            toolPicker.setVisible(true, forFirstResponder: canvas)
            isToolPickerVisible = true
            canvas.becomeFirstResponder()
        }
        .onDisappear {
            notifyDrawingChange(immediate: true)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                notifyDrawingChange(immediate: true)
            }
        }
    }

    private func restoreInitialDrawingIfNeeded() {
        guard !didRestoreInitialDrawing else { return }
        didRestoreInitialDrawing = true
        guard let initialDrawingData,
              let drawing = try? PKDrawing(data: initialDrawingData)
        else { return }
        canvas.drawing = drawing
        isDrawingEmpty = drawing.strokes.isEmpty
        drawingByteCount = initialDrawingData.count
    }

    private func scheduleDrawingChangeNotification() {
        changeNotifyTask?.cancel()
        changeNotifyTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            notifyDrawingChange(immediate: true)
        }
    }

    private func notifyDrawingChange(immediate: Bool) {
        if immediate {
            changeNotifyTask?.cancel()
        }
        let data = canvas.drawing.dataRepresentation()
        drawingByteCount = data.count
        onDrawingChange(data)
    }
}

struct CanvasUIView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    @Binding var isDrawingEmpty: Bool
    var onDrawingChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isDrawingEmpty: $isDrawingEmpty, onDrawingChange: onDrawingChange)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .systemBackground
        canvasView.isOpaque = true
        canvasView.delegate = context.coordinator
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        context.coordinator.syncEmptyState(from: canvasView)
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.isDrawingEmpty = $isDrawingEmpty
        context.coordinator.onDrawingChange = onDrawingChange
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var isDrawingEmpty: Binding<Bool>
        var onDrawingChange: () -> Void

        init(isDrawingEmpty: Binding<Bool>, onDrawingChange: @escaping () -> Void) {
            self.isDrawingEmpty = isDrawingEmpty
            self.onDrawingChange = onDrawingChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            syncEmptyState(from: canvasView)
            onDrawingChange()
        }

        func syncEmptyState(from canvasView: PKCanvasView) {
            let empty = canvasView.drawing.strokes.isEmpty
            if isDrawingEmpty.wrappedValue != empty {
                isDrawingEmpty.wrappedValue = empty
            }
        }
    }
}

#Preview {
    NavigationStack {
        CanvasView(draftSaveStatus: .constant(.saved)) { _ in }
    }
}
