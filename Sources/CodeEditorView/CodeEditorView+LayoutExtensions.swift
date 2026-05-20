import CodeEditorPlatform
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Layout & Paragraph Style

extension CodeEditorView {
    // MARK: - Paragraph Style

    /// Apply paragraph style settings for tab width and line spacing
    internal func applyParagraphStyle() {
        // Get font to use for calculations
        let font = self.font ?? PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)

        // Get cached paragraph style instead of creating new one each time
        let paragraphStyle = runtime.dependencies.paragraphStyleCache.paragraphStyle(
            tabWidth: configuration.layout.tabWidth,
            lineHeightMultiple: configuration.layout.lineHeightMultiple,
            font: font
        )

        // Apply the paragraph style to all text. Read through the TK2-safe
        // accessor; `self.textStorage` triggers Apple's TK1 compatibility shim.
        if let textStorage = textContentStorage?.textStorage {
            let range = NSRange(location: 0, length: textStorage.length)
            textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)

            #if canImport(AppKit)
            // Set as default paragraph style for new text
            defaultParagraphStyle = paragraphStyle
            #else
            // Set as typing attributes for new text
            var typingAttrs = typingAttributes
            typingAttrs[.paragraphStyle] = paragraphStyle
            typingAttributes = typingAttrs
            #endif
        }

        // Force text view to relayout and redraw
        #if canImport(AppKit)
        needsDisplay = true
        needsLayout = true
        #else
        setNeedsDisplay()
        setNeedsLayout()
        #endif
    }

    // MARK: - Layout Overrides

    #if canImport(AppKit)
    override public func layout() {
        // Ensure we're on the main thread for layout operations
        if Thread.isMainThread {
            // Save scroll position before layout
            let savedScrollPosition = enclosingScrollView?.contentView.bounds.origin

            super.layout()
            updateGutterFrame()
            updateLineHighlightFrame()
            updateAnnotationViews()

            // Restore scroll position if it was changed during layout
            if let scrollView = enclosingScrollView,
               let savedPosition = savedScrollPosition,
               scrollView.contentView.bounds.origin != savedPosition {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                scrollView.contentView.bounds.origin = savedPosition
                CATransaction.commit()
            }
        } else {
            // Use Swift concurrency to dispatch to main actor
            Task { @MainActor [weak self] in
                self?.layout()
            }
        }
    }
    #else
    override public func layoutSubviews() {
        super.layoutSubviews()
        updateGutterFrame()
        updateLineHighlightFrame()
        updateAnnotationViews()

        // Don't update text container size here to prevent configuration loops
        // Text container size is managed by configuration updates

    }
    #endif

    #if canImport(AppKit)
    override public func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        updateGutterFrame()
    }
    #endif

    #if canImport(AppKit)
    override public func setFrameSize(_ newSize: NSSize) {
        // Save scroll position before frame change
        let savedScrollPosition = enclosingScrollView?.contentView.bounds.origin

        super.setFrameSize(newSize)
        updateGutterFrame()

        // Restore scroll position if needed
        if let scrollView = enclosingScrollView,
           let savedPosition = savedScrollPosition,
           scrollView.contentView.bounds.origin != savedPosition {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            scrollView.contentView.bounds.origin = savedPosition
            CATransaction.commit()
        }
    }
    #endif

    // MARK: - Text Container Origin

    // MARK: - Text Container Management

    /// Updates the text container size based on current configuration and bounds
    internal func updateTextContainerSize() {
        #if canImport(AppKit)
        guard let textContainer = self.textContainer else { return }
        let savedScrollOrigin = enclosingScrollView?.contentView.bounds.origin
        let savedVisibleRect = enclosingScrollView?.contentView.visibleRect
        defer {
            restoreScrollOrigin(savedScrollOrigin, visibleRect: savedVisibleRect)
            restoreScrollOriginAfterLayout(savedScrollOrigin, visibleRect: savedVisibleRect)
        }

        // If we're in a container view with minimap visible, let the container handle the sizing
        if let container = containerView, container.configuration.display.isMinimapVisible {
            // The container view's layoutViewsAppKit method will handle text container sizing
            // We should not override it here
            return
        }

        if configuration.layout.wrapLines {
            // For word wrap mode, set container width to match view width
            let wrappingWidth = enclosingScrollView?.contentView.bounds.width ?? bounds.width
            textContainer.containerSize = NSSize(
                width: wrappingWidth - textContainerInset.width * 2,
                height: CGFloat.greatestFiniteMagnitude
            )

            // Ensure proper tracking settings
            textContainer.widthTracksTextView = true
            isHorizontallyResizable = false

            // Invalidate through TextKit2. Reading `textContainer.layoutManager`
            // coerces the AppKit view to TextKit1 and clears `textLayoutManager`.
            let fullRange = NSRange(location: 0, length: textKitBridge.documentLength)
            if fullRange.length > 0,
               let textRange = textKitBridge.textRangeFromNSRange(fullRange) {
                textLayoutManager?.invalidateLayout(for: textRange)
                textLayoutManager?.ensureLayout(for: textRange)
            }
        } else {
            // For non-wrapping mode, allow unlimited width
            textContainer.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )

            // Ensure proper tracking settings
            textContainer.widthTracksTextView = false
            isHorizontallyResizable = true
        }

        updateDocumentFrameForCurrentLayout()

        #else
        // iOS handles container sizing differently
        let textContainer = self.textContainer

        if configuration.layout.wrapLines {
            // Enable word wrapping
            textContainer.lineBreakMode = .byWordWrapping
            textContainer.size = CGSize(
                width: bounds.width - textContainerInset.left - textContainerInset.right,
                height: CGFloat.greatestFiniteMagnitude
            )
            textContainer.widthTracksTextView = true

            // Update scrolling behavior
            self.alwaysBounceHorizontal = false
            self.showsHorizontalScrollIndicator = false
        } else {
            // Disable word wrapping - allow horizontal scrolling
            textContainer.lineBreakMode = .byCharWrapping
            textContainer.size = CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            textContainer.widthTracksTextView = false

            // Enable horizontal scrolling
            self.alwaysBounceHorizontal = true
            self.showsHorizontalScrollIndicator = true
        }
        #endif
    }

    #if canImport(AppKit)
    private func updateDocumentFrameForCurrentLayout() {
        guard let scrollView = enclosingScrollView else { return }

        let viewportSize = scrollView.contentView.bounds.size
        var targetSize = frame.size
        if configuration.layout.wrapLines {
            targetSize.width = max(viewportSize.width, bounds.width)
        }
        if let documentHeight = textKit2DocumentHeight() {
            targetSize.height = max(viewportSize.height, documentHeight + textContainerInset.height * 2)
        }

        if targetSize != frame.size {
            setFrameSize(targetSize)
        }
    }

    private func textKit2DocumentHeight() -> CGFloat? {
        guard let textLayoutManager else { return nil }

        let documentRange = textLayoutManager.documentRange
        textLayoutManager.ensureLayout(for: documentRange)

        var maxY: CGFloat = 0
        var didFindFragment = false
        textLayoutManager.enumerateTextLayoutFragments(from: documentRange.location) { fragment in
            maxY = max(maxY, fragment.layoutFragmentFrame.maxY)
            didFindFragment = true
            return true
        }

        guard didFindFragment else {
            let font = font ?? PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
            return TextMetricsCalculator.calculateLineHeight(for: font) * configuration.layout.lineHeightMultiple
        }
        return maxY
    }

    private func restoreScrollOrigin(_ origin: NSPoint?, visibleRect: NSRect?) {
        guard let scrollView = enclosingScrollView,
              let origin,
              let visibleRect,
              visibleRect.width > 0,
              visibleRect.height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        scrollView.contentView.bounds.origin = origin
        scrollView.contentView.setBoundsOrigin(origin)
        CATransaction.commit()
    }

    private func restoreScrollOriginAfterLayout(_ origin: NSPoint?, visibleRect: NSRect?) {
        guard let origin, origin.y > 0, visibleRect != nil else { return }
        // Defer until *after* the current AppKit layout pass completes.
        // `DispatchQueue.main.async` (rather than `Task { @MainActor in … }`)
        // is deliberate here: it enqueues on the main run loop's
        // current-source-of-events queue, which AppKit drains in the same
        // turn as `viewDidEndLiveResize` and the view's own
        // `layout`/`resizeSubviews(withOldSize:)`. A `Task` would hop
        // through the cooperative-pool scheduler and could run before the
        // enclosing scroll view's pending subtree layout, so
        // `layoutSubtreeIfNeeded()` would be a no-op and the scroll
        // origin would land against stale geometry.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.enclosingScrollView?.layoutSubtreeIfNeeded()
            self.restoreScrollOrigin(origin, visibleRect: visibleRect)
        }
    }
    #endif
}
