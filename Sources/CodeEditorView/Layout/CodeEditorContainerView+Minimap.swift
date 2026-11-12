import CodeEditorPlatform
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Minimap Management

extension CodeEditorContainerView {
    // MARK: - Minimap Setup

    internal func setupMinimap() {
        // Re-running setup must drop any previously installed block
        // observers — without this, a second setup would orphan their
        // tokens and leak the closures NotificationCenter retains.
        cleanupMinimapObservers()

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
        #if canImport(AppKit)
        let textChangeToken = NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        minimapObservers.append(textChangeToken)
        #else
        let textChangeToken = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        minimapObservers.append(textChangeToken)
        #endif

        // Set up scroll observer to update the minimap. Auto-scroll to the
        // cursor reacts to selection changes only, never to scrolling: a
        // scroll that moves the caret off screen is the user's choice.
        #if canImport(AppKit)
        let scrollToken = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        minimapObservers.append(scrollToken)
        #else
        // On iOS, set up scroll delegate for minimap updates
        // The textView (UITextView) handles scrolling internally
        // We'll monitor scroll changes through the delegate pattern in setupIOSViews
        #endif
    }

    // MARK: - Cleanup

    /// Remove every block-based observer installed by `setupMinimap()`.
    /// Safe to call multiple times; also invoked from `deinit`.
    internal func cleanupMinimapObservers() {
        minimapObservers.forEach { NotificationCenter.default.removeObserver($0) }
        minimapObservers.removeAll()
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
        #if canImport(AppKit)
        minimapView.needsDisplay = true
        #else
        minimapView.setNeedsDisplay()
        #endif
    }

    // MARK: - Navigation

    private func navigateToLine(_ lineNumber: Int) {
        let lineCount = textView.lineGeometryStore.lineCount
        guard lineCount > 0 else { return }

        let targetLineIndex = min(max(0, lineNumber), lineCount - 1)
        let targetPosition = textView.lineGeometryStore.utf16Offset(forLineIndex: targetLineIndex)
        let targetRange = NSRange(location: targetPosition, length: 0)

        #if canImport(AppKit)
        guard targetPosition <= textView.string.utf16.count else { return }

        if configuration.behavior.autoScrollToCursor {
            textView.setSelectedRange(targetRange)

            var rect = textView.lineGeometryStore.estimatedRect(
                forLineAt: targetLineIndex,
                containerWidth: textView.bounds.width
            )
            rect.origin.x += textView.textContainerOrigin.x
            rect.origin.y += textView.textContainerOrigin.y
            rect.size.width = max(rect.width, 1)
            rect.size.height = max(rect.height, 20)
            textView.scrollToVisible(rect)
        } else {
            textView.setSelectedRangeWithoutScrolling(targetRange)
        }
        #else
        let text = textView.text ?? ""
        guard targetPosition <= text.utf16.count,
              let position = textView.position(from: textView.beginningOfDocument, offset: targetPosition) else {
            return
        }

        let textRange = textView.textRange(from: position, to: position)
        textView.setSelectedTextRangeWithoutScrolling(textRange)

        if configuration.behavior.autoScrollToCursor {
            var rect = textView.lineGeometryStore.estimatedRect(
                forLineAt: targetLineIndex,
                containerWidth: textView.bounds.width
            )
            rect.origin.x += textView.textContainerInset.left
            rect.origin.y += textView.textContainerInset.top
            rect.size.width = max(rect.width, 1)
            rect.size.height = max(rect.height, 20)
            textView.scrollRectToVisible(rect, animated: true)
        }
        #endif
    }
}
