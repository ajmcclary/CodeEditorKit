import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorPlatform
import CodeEditorTheming
import Foundation
#if canImport(AppKit)
import AppKit

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

        // Gutter setup is handled by `ContainerViewInitializer.setupGutterView`,
        // called from `setupPlatformViews`. No ruler-view plumbing here.

        // Apply configuration
        do {
            try textView.apply(configuration: configuration)
        } catch {
            CrossPlatformLogger.logger().error("Rejected AppKit container configuration: \(error)")
        }
    }

    /// Toggles the macOS gutter visibility and recomputes the text
    /// container's horizontal inset so text neither hides behind the
    /// floating gutter nor leaves an empty strip when line numbers are off.
    func updateMacOSGutter() {
        guard let scrollView = textView.enclosingScrollView else { return }
        let horizontalPadding = configuration.layout.lineNumberPadding

        if configuration.display.isLineNumbersEnabled {
            let gutter: CodeEditorGutterView
            if let existing = macGutterView {
                gutter = existing
            } else {
                gutter = CodeEditorGutterView(frame: NSRect(
                    x: 0,
                    y: 0,
                    width: configuration.layout.gutterWidth,
                    height: scrollView.contentView.bounds.height
                ))
                macGutterView = gutter
                gutter.attach(to: scrollView, textView: textView)
                if let theme = appliedTheme {
                    gutter.apply(theme: theme)
                }
            }
            gutter.frame.size.width = configuration.layout.gutterWidth
            textView.textContainerInset.width = baseTextContainerInsetWidth
                + configuration.layout.gutterWidth
                + horizontalPadding
            gutter.needsDisplay = true
        } else {
            macGutterView?.detach()
            macGutterView = nil
            textView.textContainerInset.width = baseTextContainerInsetWidth
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

        // Gutter has its own observers; mark dirty for any composite redraw.
        if configuration.display.isLineNumbersEnabled {
            macGutterView?.needsDisplay = true
            scrollView.needsDisplay = true
        }
    }
}

#endif
