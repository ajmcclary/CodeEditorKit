import Foundation
#if canImport(AppKit)
import AppKit
/// A ruler view that displays line numbers for macOS
@MainActor
class LineNumberRulerView: NSRulerView {
    // MARK: - Properties

    /// The text view this ruler is associated with
    weak var textView: NSTextView?

    /// Background color
    var backgroundColor = PlatformColors.controlBackground

    /// Track last vertical scroll position to avoid unnecessary redraws
    private var lastScrollY: CGFloat = 0

    /// Renderer that owns line-number drawing and themed colors. Allocated
    /// once per ruler instance; theme updates arrive via `apply(theme:)`.
    let renderer = GutterViewRenderer()

    /// Last line index containing the caret, used to short-circuit redraws on
    /// intra-line caret movement. Internal so tests can observe state changes
    /// driven by the selection observer.
    internal private(set) var lastActiveLineNumber: Int?

    // MARK: - Initialization

    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        self.clientView = scrollView?.documentView
        self.ruleThickness = 50.0 // Increased width to accommodate folding controls
        self.clipsToBounds = true // Prevent drawing outside bounds

        // Observe scroll view changes to ensure line numbers update
        if let scrollView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )

            // Also observe frame changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewDidScroll(_:)),
                name: NSView.frameDidChangeNotification,
                object: scrollView.contentView
            )
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func scrollViewDidScroll(_: Notification) {
        // Only redraw if we're scrolling vertically
        // Horizontal scrolling shouldn't require line number updates
        guard let scrollView = self.scrollView else {
            setNeedsDisplay(bounds)
            return
        }

        // Check if this is a vertical scroll by comparing the previous and current Y positions
        let currentY = scrollView.contentView.bounds.origin.y
        if !lastScrollY.isEqual(to: currentY) {
            lastScrollY = currentY
            setNeedsDisplay(bounds)
        }
        // If only X changed (horizontal scroll), don't trigger a redraw
    }

    @objc func textDidChange(_: Notification) {
        // Text changed, we need to update line numbers
        setNeedsDisplay(bounds)
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Theme

    /// Forwards a theme to the renderer and triggers a redraw. The ruler's
    /// own background color is themed elsewhere (configuration path); this
    /// method exists so `CodeEditorContainerView.apply(theme:)` can fan out
    /// to the ruler symmetrically with `GutterView.apply(theme:)`.
    @MainActor
    func apply(theme: Theme) {
        renderer.apply(theme: theme)
        needsDisplay = true
    }

    // MARK: - Active line

    /// Computes the 1-based line number containing the caret. Returns nil
    /// when no selection is set or the geometry store is empty.
    @MainActor
    private func computeActiveLineNumber(for textView: CodeEditorView) -> Int? {
        let location = textView.selectedRange().location
        guard location != NSNotFound,
              textView.lineGeometryStore.lineCount > 0 else { return nil }
        return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
    }

    /// Recomputes the active line and marks the ruler dirty only when the
    /// line index changes. Called from the selection-change observer.
    @MainActor
    func selectionDidChange() {
        guard let textView = clientView as? CodeEditorView else { return }
        let newActive = computeActiveLineNumber(for: textView)
        if newActive != lastActiveLineNumber {
            lastActiveLineNumber = newActive
            needsDisplay = true
        }
    }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        backgroundColor.set()
        rect.fill()

        guard let textView = clientView as? CodeEditorView,
              let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let activeLineNumber = computeActiveLineNumber(for: textView)
        lastActiveLineNumber = activeLineNumber

        renderer.draw(
            in: rect,
            context: context,
            textView: textView,
            gutterBounds: bounds,
            fillBackground: false,
            activeLineNumber: activeLineNumber
        )

        PlatformColors.separator.set()
        let separatorRect = NSRect(x: ruleThickness - 1, y: rect.minY, width: 1, height: rect.height)
        separatorRect.fill()
    }
}
// MARK: - MacOS Extensions
extension CodeEditorContainerView {
    /// Sets up the macOS-specific views and constraints
    func setupMacOSViews() {
        // Set up the scroll view and text view relationship
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        // Add scroll view first
        addSubview(scrollView)

        // Add minimap on top of scroll view
        addSubview(minimapView, positioned: .above, relativeTo: scrollView)

        // Ensure minimap is properly configured — gate on the same knob
        // the rest of the editor's view family uses.
        HardwareAcceleration.apply(configuration.performance.useHardwareAcceleration, to: minimapView)
        minimapView.layer?.zPosition = 1_000
        minimapView.layer?.backgroundColor = MinimapConfiguration.defaultBackgroundColor.cgColor

        // Configure scroll view for line numbers
        scrollView.hasVerticalRuler = configuration.display.isLineNumbersEnabled
        scrollView.rulersVisible = configuration.display.isLineNumbersEnabled

        if configuration.display.isLineNumbersEnabled {
            let rulerView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
            rulerView.textView = textView
            rulerView.ruleThickness = configuration.layout.gutterWidth
            scrollView.verticalRulerView = rulerView

            // Ensure ruler view is displayed
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            rulerView.needsDisplay = true

            // Observe text changes to update line numbers
            NotificationCenter.default.addObserver(
                rulerView,
                selector: #selector(rulerView.textDidChange(_:)),
                name: NSText.didChangeNotification,
                object: textView
            )
        }

        // Apply configuration
        do {
            try configuration.apply(to: textView)
        } catch {
            CrossPlatformLogger.logger().error("Rejected AppKit container configuration: \(error)")
        }
    }

    /// Updates the macOS-specific ruler view with new configuration
    func updateMacOSRuler() {
        guard let scrollView = textView.enclosingScrollView else { return }

        if configuration.display.isLineNumbersEnabled {
            if scrollView.verticalRulerView == nil {
                let rulerView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
                rulerView.textView = textView
                scrollView.verticalRulerView = rulerView

                NotificationCenter.default.addObserver(
                    forName: NSTextView.didChangeSelectionNotification,
                    object: textView,
                    queue: nil
                ) { [weak rulerView] _ in
                    MainActor.assumeIsolated {
                        rulerView?.selectionDidChange()
                    }
                }
            }

            if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
                rulerView.ruleThickness = configuration.layout.gutterWidth
                rulerView.needsDisplay = true
            }

            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true

            // Force ruler view update to ensure line numbers are visible
            scrollView.verticalRulerView?.needsDisplay = true
        } else {
            scrollView.hasVerticalRuler = false
            scrollView.rulersVisible = false
            scrollView.verticalRulerView = nil
        }
    }

    /// Layout views using AppKit-specific logic
    func layoutViewsAppKit() {
        // Calculate layout dimensions
        let minimapWidth = configuration.display.isMinimapVisible ? configuration.layout.minimapWidth : 0

        // Position scroll view to fill entire width (ruler view is inside the scroll view)
        scrollView.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width - minimapWidth,
            height: bounds.height
        )

        // Position minimap on the right
        if configuration.display.isMinimapVisible {
            // Position minimap on the right edge of the container
            let minimapX = bounds.width - minimapWidth
            minimapView.frame = CGRect(
                x: minimapX,
                y: 0,
                width: minimapWidth,
                height: bounds.height
            )

            minimapView.isHidden = false

            // Force minimap to display
            minimapView.needsDisplay = true

            // Ensure minimap is in the view hierarchy and above scroll view
            if minimapView.superview == nil {
                addSubview(minimapView, positioned: .above, relativeTo: scrollView)
            }

            // Bring to front with higher z-position
            minimapView.layer?.zPosition = 1_000

            // When minimap is shown, we need to handle text view layout differently
            // Get the actual content width (scroll view width minus ruler if present)
            let contentWidth = scrollView.contentView.bounds.width

            // Save current scroll position before any layout changes
            let savedVisibleRect = scrollView.contentView.visibleRect
            let savedScrollPosition = scrollView.contentView.bounds.origin

            if configuration.layout.wrapLines {
                // When word wrap is enabled with minimap
                // Text view should fill the scroll view width and wrap text
                textView.autoresizingMask = [.width]
                textView.isHorizontallyResizable = false

                // Set frame to match scroll view content
                textView.frame = NSRect(
                    x: 0,
                    y: 0,
                    width: contentWidth,
                    height: max(textView.frame.height, scrollView.contentView.bounds.height)
                )

                // Configure text container for word wrap
                textView.textContainer?.containerSize = NSSize(
                    width: contentWidth - textView.textContainerInset.width * 2,
                    height: CGFloat.greatestFiniteMagnitude
                )
                textView.textContainer?.widthTracksTextView = true

                // Layout has already been updated by setting the frame and container size
            } else {
                // When word wrap is disabled with minimap
                // We need to allow horizontal scrolling, so the text view must be horizontally resizable
                textView.autoresizingMask = [.height]

                // Text view MUST be horizontally resizable for horizontal scrolling to work
                textView.isHorizontallyResizable = true

                // Don't set the frame when horizontal scrolling is enabled
                // The text view will size itself based on content when isHorizontallyResizable = true

                // Set text container to unlimited width to allow horizontal scrolling
                textView.textContainer?.containerSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )

                // Text container should NOT track the text view width when we want horizontal scrolling
                textView.textContainer?.widthTracksTextView = false

                // Layout has already been updated by setting the frame and container size
            }

            // Restore scroll position after all layout changes
            // This is critical to prevent scroll position from resetting during layout
            if savedVisibleRect.width > 0 && savedVisibleRect.height > 0 {
                // IMPORTANT: We must restore the scroll position immediately, not async
                // The issue is that TextKit's layout manager might reset the scroll position
                // when it updates the text view's frame during layout

                // Force the scroll view to maintain its position
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                CATransaction.setValue(true, forKey: kCATransactionDisableActions)

                // Directly set the bounds origin to restore scroll position
                // This is more reliable than using scroll(to:) which can be overridden
                scrollView.contentView.bounds.origin = savedScrollPosition

                // Also ensure the visible rect is preserved
                scrollView.contentView.setBoundsOrigin(savedScrollPosition)

                CATransaction.commit()

                // Don't call reflectScrolledClipView - it can cause recursion
            }
        } else {
            minimapView.isHidden = true

            // Snapshot scroll position before mutating the text container —
            // toggling widthTracksTextView / isHorizontallyResizable forces a
            // TextKit reflow that resets the scroll origin to 0. Mirrors the
            // minimap-visible branch's preserve-and-restore.
            let savedVisibleRect = scrollView.contentView.visibleRect
            let savedScrollPosition = scrollView.contentView.bounds.origin

            // Restore normal behavior when minimap is hidden
            if configuration.layout.wrapLines {
                // When word wrap is enabled without minimap
                textView.autoresizingMask = [.width]
                textView.isHorizontallyResizable = false

                // Configure text container for word wrap
                textView.textContainer?.widthTracksTextView = true

                textView.frame.size.width = scrollView.contentView.bounds.width
                textView.updateTextContainerSize()
            } else {
                // When word wrap is disabled without minimap
                // Restore autoresizing mask
                textView.autoresizingMask = [.width, .height]

                // Restore horizontal resizability
                textView.isHorizontallyResizable = true

                // Restore infinite width
                textView.textContainer?.containerSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )

                // Text container should not track width when not wrapping
                textView.textContainer?.widthTracksTextView = false
            }

            // Restore scroll position immediately (not async) for the same
            // reason as the minimap-visible branch: TK2 can reset bounds.origin
            // during the reflow triggered by the container width change.
            if savedVisibleRect.width > 0 && savedVisibleRect.height > 0 {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                CATransaction.setValue(true, forKey: kCATransactionDisableActions)
                scrollView.contentView.bounds.origin = savedScrollPosition
                scrollView.contentView.setBoundsOrigin(savedScrollPosition)
                CATransaction.commit()
            }
        }

        // Update minimap after layout changes
        updateMinimap()

        // Force ruler view to update after layout changes
        if configuration.display.isLineNumbersEnabled {
            scrollView.verticalRulerView?.needsDisplay = true
            // Also mark the scroll view itself for display update
            scrollView.needsDisplay = true
            // Don't force immediate display - let it happen naturally to avoid layout recursion
            // scrollView.window?.displayIfNeeded()
            // Ensure the ruler view is visible
            scrollView.rulersVisible = true
        }
    }
}

// MARK: - Folding support for macOS
extension LineNumberRulerView {
    override func mouseDown(with event: NSEvent) {
        guard let textView = textView as? CodeEditorView,
              textView.configuration.display.isCodeFoldingEnabled else {
            super.mouseDown(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)

        // Check if click is in folding control area
        let controlSize = textView.configuration.layout.foldingControlSize
        let controlPadding = textView.configuration.layout.foldingControlPadding
        let maxX = controlPadding + controlSize

        guard point.x <= maxX else {
            super.mouseDown(with: event)
            return
        }

        // Find which line was clicked via the TextKit 2 helper.
        if let lineNumber = resolveLineNumber(at: point) {
            if textView.isFoldable(at: lineNumber) {
                _ = textView.toggleFold(at: lineNumber)
                needsDisplay = true
            }
        }

        super.mouseDown(with: event)
    }

    /// Resolves the 1-based line number at a ruler-local point through the
    /// TextKit 2 helper. Never reads `NSTextView.layoutManager`.
    private func resolveLineNumber(at point: NSPoint) -> Int? {
        guard let textView = self.textView as? CodeEditorView else { return nil }
        let textPoint = textView.convert(point, from: self)
        return TextKitLineNumberHelper(textView: textView).lineNumber(at: textPoint)
    }
}

#endif
