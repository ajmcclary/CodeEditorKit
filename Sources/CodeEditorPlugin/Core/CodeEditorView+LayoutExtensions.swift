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
        let paragraphStyle = (configuration.paragraphStyleCache ?? CodeEditorDependencies.makeParagraphStyleCache()).paragraphStyle(
            tabWidth: configuration.layout.tabWidth,
            lineHeightMultiple: configuration.layout.lineHeightMultiple,
            font: font
        )

        // Apply the paragraph style to all text
        #if canImport(AppKit)
        if let textStorage = self.textStorage {
            let range = NSRange(location: 0, length: textStorage.length)
            textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)

            // Set as default paragraph style for new text
            defaultParagraphStyle = paragraphStyle
        }
        #else
        let textStorage = self.textStorage
        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)

        // Set as typing attributes for new text
        var typingAttrs = typingAttributes
        typingAttrs[.paragraphStyle] = paragraphStyle
        typingAttributes = typingAttrs
        #endif

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

    #if canImport(AppKit)
    /// Override textContainerOrigin to account for ruler view when using NSScrollView
    override public var textContainerOrigin: NSPoint {
        let origin = super.textContainerOrigin

        // Check if we're in a scroll view with a ruler view
        if let scrollView = self.enclosingScrollView,
           scrollView.hasVerticalRuler && scrollView.rulersVisible,
           scrollView.verticalRulerView != nil {
            // Don't offset the origin - the ruler sits alongside the text view
            // The text container inset handles the internal padding
            // This prevents double offsetting
        }

        return origin
    }
    #endif

    // MARK: - Text Container Management

    /// Updates the text container size based on current configuration and bounds
    internal func updateTextContainerSize() {
        #if canImport(AppKit)
        guard let textContainer = self.textContainer else { return }

        // If we're in a container view with minimap visible, let the container handle the sizing
        if let container = containerView, container.configuration.display.isMinimapVisible {
            // The container view's layoutViewsAppKit method will handle text container sizing
            // We should not override it here
            return
        }

        if configuration.layout.wrapLines {
            // For word wrap mode, set container width to match view width
            textContainer.containerSize = NSSize(
                width: bounds.width - textContainerInset.width * 2,
                height: CGFloat.greatestFiniteMagnitude
            )

            // Ensure proper tracking settings
            textContainer.widthTracksTextView = true
            isHorizontallyResizable = false

            // Invalidate layout to force text reflow
            if let textStorage {
                textContainer.layoutManager?.invalidateLayout(
                    forCharacterRange: NSRange(location: 0, length: textStorage.length),
                    actualCharacterRange: nil
                )
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
}
