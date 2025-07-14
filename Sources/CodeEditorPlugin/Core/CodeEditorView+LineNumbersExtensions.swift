import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Line Numbers and Gutter

extension CodeEditorView {
    // MARK: - Gutter Management
    
    internal func updateGutterVisibility() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On macOS, line numbers are handled by NSRulerView in the container's scroll view
        // We should never create a GutterView on macOS
        removeGutter()
        #else
        // On iOS/Mac Catalyst, gutter is managed by the text view when used standalone
        if configuration.display.isLineNumbersEnabled {
            createGutterIfNeeded()
        } else {
            removeGutter()
        }
        #endif
    }

    private func createGutterIfNeeded() {
        guard gutterViewStorage == nil else {
            return
        }

        // First update text container inset to make room for gutter
        let gutterWidth = configuration.layout.gutterWidth
        let padding = configuration.layout.lineNumberPadding
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textContainerInset = NSSize(width: gutterWidth + padding, height: textContainerInset.height)
        #else
        textContainerInset = UIEdgeInsets(top: textContainerInset.top, left: gutterWidth + padding, bottom: textContainerInset.bottom, right: textContainerInset.right)
        #endif

        let gutter = GutterView()
        gutter.textView = self
        gutter.autoresizingMask = PlatformAutoresizing.flexibleHeight // Only resize height, not width

        // Add gutter directly to the text view since we might not be in a scroll view
        // Position it below the text content so it doesn't block text
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        addSubview(gutter, positioned: .below, relativeTo: nil)
        #else
        addSubview(gutter)
        sendSubviewToBack(gutter)
        #endif

        gutterViewStorage = gutter
        updateGutterFrame()
    }

    internal func removeGutter() {
        gutterViewStorage?.removeFromSuperview()
        gutterViewStorage = nil
        
        // Reset text container inset when gutter is removed
        let padding = configuration.layout.lineNumberPadding
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textContainerInset = NSSize(width: padding, height: textContainerInset.height)
        #else
        textContainerInset = UIEdgeInsets(top: textContainerInset.top, left: padding, bottom: textContainerInset.bottom, right: textContainerInset.right)
        #endif
    }

    internal func updateGutterFrame() {
        guard let gutter = gutterViewStorage else {
            return
        }

        layoutCoordinator.performLayout {
            // Use configuration values instead of magic numbers
            let gutterWidth = self.configuration.layout.gutterWidth
            _ = self.configuration.layout.lineNumberPadding
            
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            gutter.frame = NSRect(
                x: 0,
                y: 0,
                width: gutterWidth,
                height: self.bounds.height
            )
            #else
            // For iOS/Mac Catalyst, the gutter should be positioned fixed and not scroll with content
            // It should be tall enough to show all visible line numbers
            gutter.frame = CGRect(
                x: 0,
                y: 0,
                width: gutterWidth,
                height: self.bounds.height
            )
            #endif

            // Text container inset is already set in createGutterIfNeeded
            // No need to update it here

            // Don't update text container size here - let NSTextView handle it

            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            gutter.needsDisplay = true
            #else
            gutter.setNeedsDisplay()
            #endif
        }
    }
}
