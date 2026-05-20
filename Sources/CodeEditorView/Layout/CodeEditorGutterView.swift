#if canImport(AppKit)
import AppKit
import CodeEditorPlatform
import CodeEditorTheming

/// macOS gutter host. Attached as a floating subview of the scroll view;
/// owns the renderer, the bounds/text/selection observers, and fold-click
/// hit-testing. The cross-platform `GutterView` is the iOS-only host.
@MainActor
final class CodeEditorGutterView: NSView {
    weak var textView: CodeEditorView?
    let renderer = GutterViewRenderer()
    private(set) var lastActiveLineNumber: Int?

    /// The scroll view this gutter is attached to, if any. `addFloatingSubview`
    /// stashes the view in an internal AppKit container rather than the
    /// scroll view's direct subviews, so `superview` cannot be used as a
    /// reliable "am I attached?" signal — we track it explicitly instead.
    private(set) weak var attachedScrollView: NSScrollView?

    private var observers: [NSObjectProtocol] = []
    private var lastScrollY: CGFloat = 0

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("CodeEditorGutterView does not support NSCoder")
    }

    /// Attaches the gutter as a floating subview of `scrollView` and binds
    /// it to `textView`. Idempotent: re-attaching to the same scroll view
    /// is a no-op; re-attaching to a different scroll view tears down the
    /// previous attachment first.
    func attach(to scrollView: NSScrollView, textView: CodeEditorView) {
        if attachedScrollView === scrollView, self.textView === textView { return }
        if attachedScrollView != nil { detach() }
        self.textView = textView
        attachedScrollView = scrollView
        scrollView.addFloatingSubview(self, for: .horizontal)
        registerObservers(scrollView: scrollView, textView: textView)
    }

    /// Removes the gutter from its scroll view.
    func detach() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        removeFromSuperview()
        attachedScrollView = nil
        textView = nil
    }

    /// Forwards the theme to the renderer and marks the gutter dirty.
    func apply(theme: Theme) {
        renderer.apply(theme: theme)
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let textView,
              let context = NSGraphicsContext.current?.cgContext else { return }

        PlatformColors.controlBackground.set()
        dirtyRect.fill()

        let activeLineNumber = Self.activeLineNumber(for: textView)
        lastActiveLineNumber = activeLineNumber

        renderer.draw(
            in: dirtyRect,
            context: context,
            textView: textView,
            gutterBounds: bounds,
            fillBackground: false,
            activeLineNumber: activeLineNumber
        )

        PlatformColors.separator.set()
        NSRect(x: bounds.width - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()
    }

    // MARK: - Fold-control hit-testing

    override func mouseDown(with event: NSEvent) {
        guard let textView,
              textView.configuration.display.isCodeFoldingEnabled else {
            super.mouseDown(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let controlSize = textView.configuration.layout.foldingControlSize
        let controlPadding = textView.configuration.layout.foldingControlPadding
        let maxX = controlPadding + controlSize

        guard point.x <= maxX else {
            super.mouseDown(with: event)
            return
        }

        if let lineNumber = resolveLineNumber(at: point) {
            if textView.isFoldable(at: lineNumber) {
                _ = textView.toggleFold(at: lineNumber)
                needsDisplay = true
            }
        }
        super.mouseDown(with: event)
    }

    private func resolveLineNumber(at point: NSPoint) -> Int? {
        guard let textView else { return nil }
        let textPoint = textView.convert(point, from: self)
        return TextKitLineNumberHelper(textView: textView).lineNumber(at: textPoint)
    }

    /// Recomputes the active line and marks the gutter dirty only when the
    /// 1-based line index containing the caret has actually changed.
    func selectionDidChange() {
        guard let textView else { return }
        let newActive = Self.activeLineNumber(for: textView)
        if newActive != lastActiveLineNumber {
            lastActiveLineNumber = newActive
            needsDisplay = true
        }
    }

    private static func activeLineNumber(for textView: CodeEditorView) -> Int? {
        let location = textView.selectedRange().location
        guard location != NSNotFound,
              textView.lineGeometryStore.lineCount > 0 else { return nil }
        return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
    }

    private func registerObservers(scrollView: NSScrollView, textView: CodeEditorView) {
        scrollView.contentView.postsBoundsChangedNotifications = true

        observers.append(NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self, weak scrollView] _ in
            MainActor.assumeIsolated {
                self?.handleScrollOrResize(scrollView: scrollView)
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.needsDisplay = true
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.needsDisplay = true
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.selectionDidChange()
            }
        })
    }

    private func handleScrollOrResize(scrollView: NSScrollView?) {
        guard let scrollView else {
            needsDisplay = true
            return
        }
        let currentY = scrollView.contentView.bounds.origin.y
        if !lastScrollY.isEqual(to: currentY) {
            lastScrollY = currentY
            needsDisplay = true
        }
    }
}
#endif
