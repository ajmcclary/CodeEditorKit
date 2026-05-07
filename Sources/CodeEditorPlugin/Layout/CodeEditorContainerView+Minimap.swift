import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Minimap Management

extension CodeEditorContainerView {
    // MARK: - Minimap Setup

    internal func setupMinimap() {
        // Create data provider
        minimapDataProvider = MinimapDataProvider(textView: textView)
        minimapDataProvider?.styleDataSource = textView.rangeBasedHighlightingStyleDataSourceForTesting

        // Set up navigation callback
        minimapView.onNavigate = { [weak self] lineNumber in
            self?.navigateToLine(lineNumber)
        }

        // Initially hidden based on configuration
        minimapView.isHidden = !configuration.display.isMinimapVisible

        // Generate initial minimap data
        if configuration.display.isMinimapVisible {
            updateMinimap()
        }

        // Set up text change observer to update minimap
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        #else
        NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        #endif

        // Set up scroll observer to update minimap and handle cursor tracking
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
                self?.handleScrollCursorTracking()
            }
        }
        #else
        // On iOS, set up scroll delegate for minimap updates
        // The textView (UITextView) handles scrolling internally
        // We'll monitor scroll changes through the delegate pattern in setupIOSViews
        #endif
    }

    // MARK: - Minimap Updates

    func updateMinimap() {
        guard configuration.display.isMinimapVisible,
              let dataProvider = minimapDataProvider else {
            return
        }

        // Always try to generate data, even for empty text
        if let data = dataProvider.generateData() {
            minimapView.updateData(data)
        } else {
            // Clear data to show empty state
            minimapView.updateData(nil)
        }

        // Force redraw
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        minimapView.needsDisplay = true
        #else
        minimapView.setNeedsDisplay()
        #endif
    }

    // MARK: - Navigation

    private func navigateToLine(_ lineNumber: Int) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS navigation
        let text = textView.string
        let lines = text.components(separatedBy: .newlines)

        guard lineNumber < lines.count else { return }

        // Calculate character position for the line
        let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
        let targetPosition = lineNumber > 0 ? lineStart + 1 : 0
        let targetRange = NSRange(location: targetPosition, length: 0)

        if configuration.behavior.autoScrollToCursor {
            // When auto-scroll is enabled, set selection and explicitly scroll
            textView.setSelectedRange(targetRange)

            // Use the proper macOS scrolling method
            if let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: targetRange, actualCharacterRange: nil)
                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                let adjustedRect = CGRect(
                    x: rect.origin.x + textView.textContainerOrigin.x,
                    y: rect.origin.y + textView.textContainerOrigin.y,
                    width: max(rect.width, 1),
                    height: max(rect.height, 20)
                )
                textView.scrollToVisible(adjustedRect)
            }
        } else {
            // When auto-scroll is disabled, use the method that prevents scrolling
            textView.setSelectedRangeWithoutScrolling(targetRange)
        }
        #else
        // iOS navigation
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)

        guard lineNumber < lines.count else { return }

        // Calculate character position for the line
        let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
        if lineNumber > 0 {
            // Add 1 for the newline character
            let targetPosition = lineStart + 1
            if let position = textView.position(from: textView.beginningOfDocument, offset: targetPosition) {
                let textRange = textView.textRange(from: position, to: position)

                // Use the new method that respects autoScrollToCursor configuration
                textView.setSelectedTextRangeWithoutScrolling(textRange)

                // Only scroll if autoScrollToCursor is enabled
                if configuration.behavior.autoScrollToCursor {
                    let rect = textView.caretRect(for: position)
                    textView.scrollRectToVisible(rect, animated: true)
                }
            }
        } else {
            // First line
            let textRange = textView.textRange(from: textView.beginningOfDocument, to: textView.beginningOfDocument)

            // Use the new method that respects autoScrollToCursor configuration
            textView.setSelectedTextRangeWithoutScrolling(textRange)

            // Only scroll if autoScrollToCursor is enabled
            if configuration.behavior.autoScrollToCursor {
                textView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
            }
        }
        #endif
    }

    // MARK: - Cursor Tracking During Scroll

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    internal func handleScrollCursorTracking() {
        // Only auto-scroll to cursor if autoScrollToCursor is enabled
        guard configuration.behavior.autoScrollToCursor else { return }

        // Get current cursor position
        let currentSelection = textView.selectedRange
        guard currentSelection.length == 0 else { return } // Only work with cursor, not selections

        // Get cursor position information
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let cursorPosition = currentSelection.location
        let textLength = textView.string.count
        guard cursorPosition < textLength else { return }

        // Calculate cursor rect
        let glyphRange = layoutManager.glyphRange(forCharacterRange: currentSelection, actualCharacterRange: nil)
        let cursorRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let adjustedCursorRect = CGRect(
            x: cursorRect.origin.x + textView.textContainerOrigin.x,
            y: cursorRect.origin.y + textView.textContainerOrigin.y,
            width: max(cursorRect.width, 1),
            height: max(cursorRect.height, 20)
        )

        // Check if cursor is visible in current view
        let visibleRect = textView.visibleRect
        let isVisible = visibleRect.intersects(adjustedCursorRect)

        // If cursor is not visible, scroll to make it visible
        if !isVisible {
            textView.scrollToVisible(adjustedCursorRect)
        }
    }
    #endif
}
