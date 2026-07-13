#if canImport(AppKit)
import AppKit
import CodeEditorPlatform
import DesignKitThemes

/// macOS line-number gutter hosted by `NSScrollView.verticalRulerView`.
///
/// Keeping the gutter in AppKit's ruler slot avoids the partial invalidation
/// and layer compositing behavior of `addFloatingSubview(_:for:)` during
/// vertical scrolling.
@MainActor
final class LineNumberRulerView: NSRulerView {
    weak var textView: CodeEditorView? {
        didSet {
            clientView = textView
        }
    }

    let renderer = GutterViewRenderer()
    private(set) var lastActiveLineNumber: Int?

    private var lastScrollY: CGFloat = 0

    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        textView = scrollView?.documentView as? CodeEditorView
        clientView = textView
        ruleThickness = 50
        clipsToBounds = true

        if let scrollView {
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollView.contentView.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewDidScrollOrResize(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewDidScrollOrResize(_:)),
                name: NSView.frameDidChangeNotification,
                object: scrollView.contentView
            )
        }
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("LineNumberRulerView does not support NSCoder")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func apply(theme: Theme) {
        renderer.apply(theme: theme)
        needsDisplay = true
    }

    func selectionDidChange() {
        guard let textView = resolvedTextView else { return }
        let newActive = Self.activeLineNumber(for: textView)
        if newActive != lastActiveLineNumber {
            lastActiveLineNumber = newActive
            needsDisplay = true
        }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = resolvedTextView,
              let context = NSGraphicsContext.current?.cgContext else { return }

        let activeLineNumber = Self.activeLineNumber(for: textView)
        lastActiveLineNumber = activeLineNumber

        renderer.draw(
            in: rect,
            context: context,
            textView: textView,
            gutterBounds: bounds,
            fillBackground: false,
            activeLineNumber: activeLineNumber
        )
    }

    override func mouseDown(with event: NSEvent) {
        guard let textView = resolvedTextView,
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

        if let lineNumber = resolveLineNumber(at: point),
           textView.isFoldable(at: lineNumber) {
            _ = textView.toggleFold(at: lineNumber)
            needsDisplay = true
        }

        super.mouseDown(with: event)
    }

    @objc private func scrollViewDidScrollOrResize(_: Notification) {
        guard let scrollView else {
            setNeedsDisplay(bounds)
            return
        }

        let currentY = scrollView.contentView.bounds.origin.y
        if !lastScrollY.isEqual(to: currentY) {
            lastScrollY = currentY
            setNeedsDisplay(bounds)
        } else {
            setNeedsDisplay(bounds)
        }
    }

    @objc func textDidChange(_: Notification) {
        setNeedsDisplay(bounds)
    }

    @objc private func selectionDidChangeNotification(_: Notification) {
        selectionDidChange()
    }

    func observeTextAndSelectionChanges(for textView: CodeEditorView) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChangeNotification(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
    }

    private var resolvedTextView: CodeEditorView? {
        if let textView { return textView }
        return clientView as? CodeEditorView
    }

    private func resolveLineNumber(at point: NSPoint) -> Int? {
        guard let textView = resolvedTextView else { return nil }
        let textPoint = textView.convert(point, from: self)
        return TextKitLineNumberHelper(textView: textView).lineNumber(at: textPoint)
    }

    private static func activeLineNumber(for textView: CodeEditorView) -> Int? {
        let location = textView.selectedRange().location
        guard location != NSNotFound,
              textView.lineGeometryStore.lineCount > 0 else { return nil }
        return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
    }
}
#endif
