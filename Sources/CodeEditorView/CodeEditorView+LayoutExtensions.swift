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

    /// Apply paragraph style settings for tab width and line spacing, and
    /// the character spacing.
    /// The persistent attributes the editor stamps on ordinary text: its
    /// paragraph style, font and (once a theme is applied) the theme
    /// foreground. Used to restore text whose attributes were overwritten,
    /// such as the body of an unfolded region.
    internal func baseTextAttributes() -> [NSAttributedString.Key: Any] {
        let font = self.font ?? PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: runtime.dependencies.paragraphStyleCache.paragraphStyle(
                tabWidth: configuration.layout.tabWidth,
                lineHeightMultiple: configuration.layout.lineHeightMultiple,
                font: font
            )
        ]
        if let theme = appliedTheme {
            attributes[.foregroundColor] = PlatformColor(tokens: theme.style.editor.foreground)
        } else if let textColor {
            attributes[.foregroundColor] = textColor
        }
        return attributes
    }

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

            // Character spacing is kerning on the text itself; layout reads
            // it from the storage, so rendering attributes cannot carry it.
            let characterSpacing = configuration.layout.characterSpacing
            var typingAttrs = typingAttributes
            if characterSpacing != 0 {
                textStorage.addAttribute(.kern, value: characterSpacing, range: range)
                typingAttrs[.kern] = characterSpacing
            } else {
                textStorage.removeAttribute(.kern, range: range)
                typingAttrs[.kern] = nil
            }

            #if canImport(AppKit)
            // Set as default paragraph style for new text
            defaultParagraphStyle = paragraphStyle
            #else
            // Set as typing attributes for new text
            typingAttrs[.paragraphStyle] = paragraphStyle
            #endif
            typingAttributes = typingAttrs
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
            let clock = ContinuousClock()
            let layoutStart = clock.now

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

            renderingMetrics.recordLayoutPass(
                duration: layoutStart.duration(to: clock.now),
                visibleFragmentCount: observedVisibleTextLayoutFragmentCount()
            )
        } else {
            // Use Swift concurrency to dispatch to main actor
            Task { @MainActor [weak self] in
                self?.layout()
            }
        }
    }
    #else
    override public func layoutSubviews() {
        let clock = ContinuousClock()
        let layoutStart = clock.now

        super.layoutSubviews()
        updateGutterFrame()
        updateLineHighlightFrame()
        updateAnnotationViews()

        renderingMetrics.recordLayoutPass(
            duration: layoutStart.duration(to: clock.now),
            visibleFragmentCount: observedVisibleTextLayoutFragmentCount()
        )

        // Don't update text container size here to prevent configuration loops
        // Text container size is managed by configuration updates

    }
    #endif

    private func observedVisibleTextLayoutFragmentCount() -> Int {
        guard let textLayoutManager else { return 0 }

        // Fragment frames are in the text container's coordinates.
        #if canImport(AppKit)
        let viewport = visibleContainerRect
        #else
        let viewport = bounds
        #endif
        let start = textLayoutManager.textViewportLayoutController.viewportRange?.location
            ?? textLayoutManager.documentRange.location
        var count = 0

        textLayoutManager.enumerateTextLayoutFragments(from: start) { fragment in
            let frame = fragment.layoutFragmentFrame
            if frame.minY > viewport.maxY {
                return false
            }
            if frame.intersects(viewport) {
                count += 1
            }
            return true
        }

        return count
    }

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
        applyWrapWidthFraction()

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
                width: wrappingWidth - unifiedTextContainerInsets.totalHorizontal,
                height: CGFloat.greatestFiniteMagnitude
            )

            // Ensure proper tracking settings
            textContainer.widthTracksTextView = true
            isHorizontallyResizable = false
            applyWrapWidthFraction()

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
            let fraction = wrapWidthFraction
            textContainer.size = CGSize(
                width: (bounds.width - textContainerInset.left - textContainerInset.right) * fraction,
                height: CGFloat.greatestFiniteMagnitude
            )
            // A tracking container always takes the view's full width.
            textContainer.widthTracksTextView = fraction >= 1

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

    /// `layout.textContainerWidthFraction`, limited to a width text can be
    /// laid out in.
    internal var wrapWidthFraction: CGFloat {
        min(max(configuration.layout.textContainerWidthFraction, 0.1), 1)
    }

    #if canImport(AppKit)
    /// Narrows the wrapping width to `layout.textContainerWidthFraction` of
    /// the editor's width.
    ///
    /// Every site that sizes the container for wrapping sets it to the full
    /// width, tracking the view; this runs after them. A tracking container
    /// always takes the view's full width, so a narrower one stops tracking
    /// and is resized here whenever the view's width changes.
    internal func applyWrapWidthFraction() {
        guard configuration.layout.wrapLines, let textContainer else { return }
        let fraction = wrapWidthFraction
        guard fraction < 1 else { return }

        let viewWidth = enclosingScrollView?.contentView.bounds.width ?? bounds.width
        let fullWidth = viewWidth - unifiedTextContainerInsets.totalHorizontal
        guard fullWidth > 0 else { return }

        textContainer.widthTracksTextView = false
        let width = (fullWidth * fraction).rounded(.down)
        if abs(textContainer.containerSize.width - width) > 0.5 {
            textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    private func updateDocumentFrameForCurrentLayout() {
        guard let scrollView = enclosingScrollView else { return }

        let viewportSize = scrollView.contentView.bounds.size
        var targetSize = frame.size
        if configuration.layout.wrapLines {
            targetSize.width = max(viewportSize.width, bounds.width)
        }
        if let documentHeight = textKit2DocumentHeight() {
            targetSize.height = max(viewportSize.height, documentHeight + unifiedTextContainerInsets.totalVertical)
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
