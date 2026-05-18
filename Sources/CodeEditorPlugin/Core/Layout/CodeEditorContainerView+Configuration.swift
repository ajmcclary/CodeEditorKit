import CodeEditorPlatform
import Foundation
#if canImport(AppKit)
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
        CodeEditorRenderingDiagnostics.logContainerConfigurationDispatch(
            "container.applyConfiguration.begin",
            container: self
        )

        // Snapshot scroll position before mutating layout — toggling
        // wrapLines / widthTracksTextView triggers a TextKit reflow that
        // resets scrollView.contentView.bounds.origin to 0 on macOS.
        // Restored at the bottom of this method.
        #if canImport(AppKit)
        let savedScrollOrigin = scrollView.contentView.bounds.origin
        let savedDocumentVisibleRect = scrollView.contentView.visibleRect
        #endif

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
            #if canImport(AppKit)
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
        #if canImport(AppKit)
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
        #if canImport(AppKit)
        needsLayout = true
        #else
        setNeedsLayout()
        #endif

        // Update minimap if it's now visible
        if configuration.display.isMinimapVisible {
            updateMinimap()
        }

        // Force redraw of all subviews
        #if canImport(AppKit)
        needsDisplay = true
        scrollView.needsDisplay = true
        textView.needsDisplay = true

        // Restore scroll position after layout-affecting mutations above.
        // CATransaction with disabled actions prevents an animation flash
        // and matches the pattern used in layoutViewsAppKit's minimap branch.
        if savedDocumentVisibleRect.width > 0 && savedDocumentVisibleRect.height > 0 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setValue(true, forKey: kCATransactionDisableActions)
            scrollView.contentView.bounds.origin = savedScrollOrigin
            scrollView.contentView.setBoundsOrigin(savedScrollOrigin)
            CATransaction.commit()
        }
        #else
        setNeedsDisplay()
        #endif
        CodeEditorRenderingDiagnostics.logContainerConfigurationDispatch(
            "container.applyConfiguration.end",
            container: self
        )
    }

    // MARK: - Text Container Insets

    internal func updateTextContainerInsets() {
        let padding = configuration.layout.lineNumberPadding
        let gutterWidth = showsLineNumbers ? configuration.layout.gutterWidth : 0
        let minimapWidth = configuration.display.isMinimapVisible ? configuration.layout.minimapWidth : 0

        #if canImport(AppKit)
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
        // On iOS, update edge insets
        let currentInsets = textView.textContainerEdgeInsets

        #if true
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
