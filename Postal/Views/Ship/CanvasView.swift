//
//  CanvasView.swift
//  Postal
//
//  Created by Jack Kroll on 7/21/26.
//

import SwiftUI
import PencilKit
#if DEBUG
import UniformTypeIdentifiers
#endif

struct CanvasView: View {
    let initialDrawingData: Data?
    @Binding var draftSaveStatus: DraftSaveStatus
    let limits: LetterLimits?
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
    @State private var zoomResetToken = 0
    @State private var focusDrawingToken = 0
    #if DEBUG
    @State private var isPKDrawingExportPresented = false
    @State private var pkDrawingExportDocument = PKDrawingExportDocument(data: Data())

    private var showsDeveloperExport: Bool {
        !ScreenshotMode.hidesDeveloperUI
    }
    #endif

    init(
        initialDrawingData: Data? = nil,
        draftSaveStatus: Binding<DraftSaveStatus> = .constant(.hidden),
        limits: LetterLimits? = nil,
        onDrawingChange: @escaping (Data) -> Void = { _ in },
        onContinue: @escaping (Data) -> Void
    ) {
        self.initialDrawingData = initialDrawingData
        _draftSaveStatus = draftSaveStatus
        self.limits = limits
        self.onDrawingChange = onDrawingChange
        self.onContinue = onContinue
    }

    private var isOverLimit: Bool {
        guard let limits else { return false }
        return limits.exceedsLimit(drawingByteCount, for: .drawing)
    }

    var body: some View {
        VStack(spacing: 0) {
            CanvasUIView(
                canvasView: $canvas,
                toolPicker: $toolPicker,
                isDrawingEmpty: $isDrawingEmpty,
                zoomResetToken: zoomResetToken,
                focusDrawingToken: focusDrawingToken,
                onDrawingChange: scheduleDrawingChangeNotification
            )
            .ignoresSafeArea(.all)
            .background(Color(.systemBackground))
        }
        .safeAreaInset(edge: .top) {
            if let limits {
                LetterComposerStatusBar(
                    draftSaveStatus: $draftSaveStatus,
                    byteCount: drawingByteCount,
                    kind: .drawing,
                    limits: limits
                )
            }
        }
        .navigationTitle("Draw Letter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, *), draftSaveStatus != .hidden {
                ToolbarItem(id: "draft-save-status", placement: .subtitle) {
                    DraftSaveStatusLabel(status: draftSaveStatus)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    zoomResetToken &+= 1
                } label: {
                    Label("Reset View", systemImage: "square.arrowtriangle.4.outward")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isToolPickerVisible.toggle()
                    toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvas)
                    canvas.becomeFirstResponder()
                } label: {
                    Label(isToolPickerVisible ? "Hide Tools" : "Show Tools", systemImage: isToolPickerVisible ? "pencil.slash" : "pencil")
                }
            }
            #if DEBUG
            if showsDeveloperExport {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            notifyDrawingChange(immediate: true)
                            pkDrawingExportDocument = PKDrawingExportDocument(
                                data: canvas.drawing.dataRepresentation()
                            )
                            isPKDrawingExportPresented = true
                        } label: {
                            Label("Export PK Drawing", systemImage: "square.and.arrow.up")
                        }
                        .disabled(isDrawingEmpty)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            #endif
            ToolbarItem(placement: .bottomBar) {
                Button {
                    changeNotifyTask?.cancel()
                    canvas = PKCanvasView()
                    isToolPickerVisible = true
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
        #if DEBUG
        .fileExporter(
            isPresented: Binding(
                get: { showsDeveloperExport && isPKDrawingExportPresented },
                set: { newValue in
                    guard showsDeveloperExport else { return }
                    isPKDrawingExportPresented = newValue
                }
            ),
            document: pkDrawingExportDocument,
            contentType: .pkDrawing,
            defaultFilename: "letter"
        ) { _ in }
        #endif
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
        focusDrawingToken += 1
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
    let zoomResetToken: Int
    let focusDrawingToken: Int
    var onDrawingChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isDrawingEmpty: $isDrawingEmpty, onDrawingChange: onDrawingChange)
    }

    func makeUIView(context: Context) -> CanvasContainerView {
        configureCanvasView(canvasView, coordinator: context.coordinator)
        context.coordinator.syncEmptyState(from: canvasView)

        let container = CanvasContainerView()
        container.install(canvasView: canvasView)
        container.syncCanvasExtent(for: canvasView.drawing)
        context.coordinator.containerView = container
        return container
    }

    func updateUIView(_ uiView: CanvasContainerView, context: Context) {
        context.coordinator.isDrawingEmpty = $isDrawingEmpty
        context.coordinator.onDrawingChange = onDrawingChange
        if uiView.canvasView !== canvasView {
            if let previousCanvas = uiView.canvasView {
                toolPicker.removeObserver(previousCanvas)
            }
            configureCanvasView(canvasView, coordinator: context.coordinator)
            uiView.install(canvasView: canvasView)
            uiView.syncCanvasExtent(for: canvasView.drawing)
            context.coordinator.containerView = uiView
            context.coordinator.syncEmptyState(from: canvasView)
        }
        if context.coordinator.lastZoomResetToken != zoomResetToken {
            context.coordinator.lastZoomResetToken = zoomResetToken
            uiView.resetView(animated: true)
        }
        if context.coordinator.lastFocusDrawingToken != focusDrawingToken {
            context.coordinator.lastFocusDrawingToken = focusDrawingToken
            uiView.syncCanvasExtent(for: canvasView.drawing)
            let drawing = canvasView.drawing
            DispatchQueue.main.async {
                uiView.focusOnDrawing(drawing, animated: false)
            }
            if uiView.traitCollection.userInterfaceIdiom == .phone {
                // Tool picker layout on iPhone can settle after the first pass.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    uiView.focusOnDrawing(drawing, animated: false)
                }
            }
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var isDrawingEmpty: Binding<Bool>
        var onDrawingChange: () -> Void
        var lastZoomResetToken: Int = 0
        var lastFocusDrawingToken: Int = 0
        weak var containerView: CanvasContainerView?

        init(isDrawingEmpty: Binding<Bool>, onDrawingChange: @escaping () -> Void) {
            self.isDrawingEmpty = isDrawingEmpty
            self.onDrawingChange = onDrawingChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            syncEmptyState(from: canvasView)
            containerView?.syncCanvasExtent(for: canvasView.drawing)
            onDrawingChange()
        }

        func syncEmptyState(from canvasView: PKCanvasView) {
            let empty = canvasView.drawing.strokes.isEmpty
            if isDrawingEmpty.wrappedValue != empty {
                isDrawingEmpty.wrappedValue = empty
            }
        }
    }

    private func configureCanvasView(_ canvasView: PKCanvasView, coordinator: Coordinator) {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .systemBackground
        canvasView.isOpaque = true
        canvasView.delegate = coordinator
        canvasView.isScrollEnabled = false
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
    }
}

final class CanvasContainerView: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let canvasHostView = UIView()
    private var canvasWidthConstraint: NSLayoutConstraint?
    private var canvasHeightConstraint: NSLayoutConstraint?

    weak var canvasView: PKCanvasView?

    private let minCanvasDimension: CGFloat = 1200
    private let baseCanvasScale: CGFloat = 1.8
    private let verticalGrowthPadding: CGFloat = 420
    private let verticalGrowthStep: CGFloat = 200
    private var contentDrivenCanvasHeight: CGFloat = 0
    private var suppressAutoCentering = false
    private var pendingFocusDrawing: PKDrawing?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupScrollView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollView()
    }

    func install(canvasView: PKCanvasView) {
        if self.canvasView === canvasView {
            return
        }

        self.canvasView?.removeFromSuperview()
        self.canvasView = canvasView

        pinCanvasView(canvasView)

        // Keep drawing as the primary interaction. Two-finger gestures navigate.
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        scrollView.panGestureRecognizer.maximumNumberOfTouches = 2
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCanvasSize()
        centerCanvasIfNeeded()
        if let drawing = pendingFocusDrawing,
           scrollView.bounds.width > 0,
           scrollView.bounds.height > 0 {
            focusOnDrawing(drawing, animated: false)
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        canvasHostView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerCanvasIfNeeded()
    }

    private func setupScrollView() {
        backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 125
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        canvasHostView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(canvasHostView)

        canvasWidthConstraint = canvasHostView.widthAnchor.constraint(equalToConstant: minCanvasDimension)
        canvasHeightConstraint = canvasHostView.heightAnchor.constraint(equalToConstant: minCanvasDimension)
        canvasWidthConstraint?.isActive = true
        canvasHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            canvasHostView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            canvasHostView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            canvasHostView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            canvasHostView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])
    }

    private func updateCanvasSize() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let targetWidth = max(bounds.width * baseCanvasScale, minCanvasDimension)
        let baseHeight = max(bounds.height * baseCanvasScale, minCanvasDimension)
        let targetHeight = max(baseHeight, contentDrivenCanvasHeight)

        guard canvasWidthConstraint?.constant != targetWidth ||
                canvasHeightConstraint?.constant != targetHeight else {
            return
        }

        canvasWidthConstraint?.constant = targetWidth
        canvasHeightConstraint?.constant = targetHeight
        layoutIfNeeded()
    }

    func syncCanvasExtent(for drawing: PKDrawing) {
        let baseHeight = max(bounds.height * baseCanvasScale, minCanvasDimension)
        let grownHeight: CGFloat

        if drawing.strokes.isEmpty {
            grownHeight = 0
        } else {
            let neededHeight = max(drawing.bounds.maxY + verticalGrowthPadding, baseHeight)
            grownHeight = Self.roundUp(neededHeight, step: verticalGrowthStep)
        }

        guard abs(contentDrivenCanvasHeight - grownHeight) > 0.5 else { return }
        contentDrivenCanvasHeight = grownHeight
        updateCanvasSize()
        centerCanvasIfNeeded()
    }

    private func centerCanvasIfNeeded() {
        guard !suppressAutoCentering else { return }

        let boundsSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize

        let horizontalInset = max((boundsSize.width - contentSize.width) / 2, 0)
        let verticalInset = max((boundsSize.height - contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    func resetView(animated: Bool) {
        suppressAutoCentering = false
        // Animate zoom back to default only (no recentering).
        scrollView.setZoomScale(1, animated: animated)
        scrollView.layoutIfNeeded()
    }

    /// Non-safe-area UI chrome that reduces the unobscured drawing area.
    private var focusFramingChromeInsets: UIEdgeInsets {
        switch traitCollection.userInterfaceIdiom {
        case .pad:
            return UIEdgeInsets(top: 12, left: 0, bottom: 96, right: 0)
        default:
            // iPhone PencilKit tool picker + bottom toolbar cover most of the lower edge.
            return UIEdgeInsets(top: 12, left: 20, bottom: 300, right: 20)
        }
    }

    /// Safe area plus surrounding chrome for framing restored drawings.
    private var focusFramingInsets: UIEdgeInsets {
        let chrome = focusFramingChromeInsets
        return UIEdgeInsets(
            top: safeAreaInsets.top + chrome.top,
            left: safeAreaInsets.left + chrome.left,
            bottom: safeAreaInsets.bottom + chrome.bottom,
            right: safeAreaInsets.right + chrome.right
        )
    }

    /// Scrolls so restored or imported drawing content is comfortably in view.
    func focusOnDrawing(_ drawing: PKDrawing, animated: Bool) {
        guard !drawing.strokes.isEmpty else { return }

        guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else {
            pendingFocusDrawing = drawing
            return
        }
        pendingFocusDrawing = nil

        layoutIfNeeded()
        suppressAutoCentering = true

        let target = drawing.bounds.insetBy(dx: -48, dy: -48)
        guard target.width > 0, target.height > 0 else { return }

        let framing = focusFramingInsets
        let visibleWidth = scrollView.bounds.width - framing.left - framing.right
        let visibleHeight = scrollView.bounds.height - framing.top - framing.bottom
        guard visibleWidth > 0, visibleHeight > 0 else {
            pendingFocusDrawing = drawing
            return
        }

        let clampedScale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if traitCollection.userInterfaceIdiom == .phone {
            // Anchor from the top — letters are written downward and the tool picker
            // eats the bottom. Vertical centering scrolls the top out of view on iPhone.
            let widthScale = visibleWidth / target.width
            let heightScale = visibleHeight / target.height
            let scale = min(widthScale, heightScale, 1) * 0.96
            clampedScale = max(scale, scrollView.minimumZoomScale)
            offsetX = target.minX * clampedScale - framing.left
            offsetY = target.minY * clampedScale - framing.top
        } else {
            let widthScale = visibleWidth / target.width
            let heightScale = visibleHeight / target.height
            let scale = min(widthScale, heightScale, 1) * 0.93
            clampedScale = max(scale, scrollView.minimumZoomScale)
            offsetX = target.midX * clampedScale - framing.left - visibleWidth / 2
            offsetY = target.midY * clampedScale - framing.top - visibleHeight / 2
        }

        scrollView.contentInset = framing
        scrollView.setZoomScale(clampedScale, animated: false)
        scrollView.layoutIfNeeded()

        let minX = -scrollView.contentInset.left
        let minY = -scrollView.contentInset.top
        let maxX = max(scrollView.contentSize.width - scrollView.bounds.width + scrollView.contentInset.right, minX)
        let maxY = max(scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom, minY)
        scrollView.contentOffset = CGPoint(
            x: min(max(offsetX, minX), maxX),
            y: min(max(offsetY, minY), maxY)
        )
    }

    private static func roundUp(_ value: CGFloat, step: CGFloat) -> CGFloat {
        guard step > 0 else { return value }
        return ceil(value / step) * step
    }

    private func pinCanvasView(_ canvasView: PKCanvasView) {
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasHostView.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: canvasHostView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: canvasHostView.trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: canvasHostView.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: canvasHostView.bottomAnchor)
        ])
    }
}

#if DEBUG
private struct PKDrawingExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pkDrawing] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private extension UTType {
    static let pkDrawing = UTType(
        exportedAs: "com.apple.pencilkit.drawing",
        conformingTo: .data
    )
}
#endif

#Preview {
    NavigationStack {
        CanvasView(
            draftSaveStatus: .constant(.saved),
            limits: .preview
        ) { _ in }
    }
}
