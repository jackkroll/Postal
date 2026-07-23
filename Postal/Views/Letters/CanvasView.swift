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
    let onContinue: (Data) -> Void

    @State private var canvas = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var isDrawingEmpty = true
    @State private var isToolPickerVisible = true
    @State private var didRestoreInitialDrawing = false

    init(initialDrawingData: Data? = nil, onContinue: @escaping (Data) -> Void) {
        self.initialDrawingData = initialDrawingData
        self.onContinue = onContinue
    }

    var body: some View {
        CanvasUIView(
            canvasView: $canvas,
            toolPicker: $toolPicker,
            isDrawingEmpty: $isDrawingEmpty
        )
        .background(Color(.systemBackground))
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
                } label: {
                    Label("Clear", systemImage: "trashcan.fill")
                        .labelStyle(.iconOnly)
                }
                .disabled(isDrawingEmpty)
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    onContinue(canvas.drawing.dataRepresentation())
                } label: {
                    Label("Continue", systemImage: "chevron.forward")
                }
                .disabled(isDrawingEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            restoreInitialDrawingIfNeeded()
            toolPicker.setVisible(true, forFirstResponder: canvas)
            isToolPickerVisible = true
            canvas.becomeFirstResponder()
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
    }
}

struct CanvasUIView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    @Binding var isDrawingEmpty: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isDrawingEmpty: $isDrawingEmpty)
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
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var isDrawingEmpty: Binding<Bool>

        init(isDrawingEmpty: Binding<Bool>) {
            self.isDrawingEmpty = isDrawingEmpty
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            syncEmptyState(from: canvasView)
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
        CanvasView { _ in }
    }
}
