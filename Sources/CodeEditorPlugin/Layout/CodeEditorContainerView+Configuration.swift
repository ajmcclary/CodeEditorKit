import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Configuration Management

extension CodeEditorContainerView {
    // MARK: - Configuration

    /// Applies the current configuration to all editor components
    /// Updates text view, gutter, minimap, and other UI elements based on configuration changes
    public func applyConfiguration() {
        // Prevent re-entrant calls
        guard !isApplyingConfiguration else { return }
        isApplyingConfiguration = true
        defer { isApplyingConfiguration = false }

        // Apply configuration to text view, but disable its internal line numbers
        // since we manage the gutter externally
        var textViewConfig = configuration
        textViewConfig.display.isLineNumbersEnabled = false

        // First remove any existing internal gutter from text view
        textView.removeGutter()

        // Then apply the configuration with line numbers disabled
        textView.configuration = textViewConfig

        // Update our own properties based on configuration
        showsLineNumbers = configuration.display.isLineNumbersEnabled

        // Update minimap visibility
        minimapView.isHidden = !configuration.display.isMinimapVisible

        // Force minimap to redraw when shown
        if configuration.display.isMinimapVisible {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            minimapView.needsDisplay = true
            #else
            minimapView.setNeedsDisplay()
            #endif
        }

        // Update platform-specific UI elements
        #if canImport(UIKit)
        updateIOSGutter()
        #endif

        // Update scroll view settings on macOS
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        scrollView.hasHorizontalScroller = !configuration.layout.wrapLines

        // Update ruler visibility and settings
        scrollView.hasVerticalRuler = configuration.display.isLineNumbersEnabled
        scrollView.rulersVisible = configuration.display.isLineNumbersEnabled
        if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
            rulerView.ruleThickness = configuration.layout.gutterWidth
            rulerView.clipsToBounds = true
            rulerView.needsDisplay = true
        }
        // Don't set horizontal resizability here - it will be handled in layoutViews
        // based on minimap visibility
        if !configuration.display.isMinimapVisible {
            textView.isHorizontallyResizable = !configuration.layout.wrapLines
            textView.textContainer?.widthTracksTextView = configuration.layout.wrapLines
        }

        if !configuration.layout.wrapLines && !configuration.display.isMinimapVisible {
            // Only set infinite width if minimap is not shown
            // When minimap is shown, layoutViews will handle the sizing
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        #endif

        // Update text container insets when configuration changes (for all platforms)
        updateTextContainerInsets()

        // Request layout update without forcing immediate layout
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsLayout = true
        #else
        setNeedsLayout()
        #endif

        // Update minimap if it's now visible
        if configuration.display.isMinimapVisible {
            updateMinimap()
        }

        // Force redraw of all subviews
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsDisplay = true
        scrollView.needsDisplay = true
        textView.needsDisplay = true
        #else
        setNeedsDisplay()
        #endif
    }

    // MARK: - Text Container Insets

    internal func updateTextContainerInsets() {
        let padding = configuration.layout.lineNumberPadding
        let gutterWidth = showsLineNumbers ? configuration.layout.gutterWidth : 0
        let minimapWidth = configuration.display.isMinimapVisible ? configuration.layout.minimapWidth : 0

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On macOS, we use ruler view for line numbers, so text container insets work differently
        // When line numbers are shown: ruler view handles the spacing, minimal text inset needed
        // When line numbers are hidden: no ruler view, so minimal padding only
        let currentInsets = textView.textContainerInset
        let leftInset = showsLineNumbers ? padding : padding / 2  // Reduced when hidden
        textView.textContainerInset = NSSize(
            width: leftInset,
            height: currentInsets.height
        )
        #else
        // On iOS/Catalyst, update edge insets
        let currentInsets = textView.textContainerEdgeInsets

        #if targetEnvironment(macCatalyst)
        // For Mac Catalyst, the text view is positioned after the gutter
        // so we only need padding, not gutterWidth + padding
        let newInsets = EdgeInsets(
            top: currentInsets.top,
            left: padding,  // Only padding since text view is positioned after gutter
            bottom: currentInsets.bottom,
            right: minimapWidth + padding
        )
        #else
        // For iOS, only include gutter width if line numbers are actually shown
        let leftInset = showsLineNumbers ? (gutterWidth + padding) : padding
        let newInsets = EdgeInsets(
            top: currentInsets.top,
            left: leftInset,
            bottom: currentInsets.bottom,
            right: minimapWidth + padding
        )
        #endif

        textView.setTextContainerEdgeInsets(newInsets)
        #endif
    }
}
