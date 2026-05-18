import Foundation
#if canImport(UIKit)
import UIKit

// MARK: - Keyboard Handling

extension CodeEditorContainerView {
    // MARK: - Keyboard Observers

    internal func setupKeyboardObservers() {
        // Defensive: drop any tokens from a prior setup pass so we never orphan
        // block-based observers if this method is invoked more than once.
        cleanupKeyboardObservers()

        // Listen for keyboard notifications
        let willShow = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Extract data from notification before entering Task
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double

            Task { @MainActor in
                self.handleKeyboardWillShow(keyboardFrame: keyboardFrame, duration: duration)
            }
        }

        let willHide = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Extract data from notification before entering Task
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double

            Task { @MainActor in
                self.handleKeyboardWillHide(duration: duration)
            }
        }

        keyboardObservers = [willShow, willHide]
    }

    // MARK: - Keyboard Event Handling

    private func handleKeyboardWillShow(keyboardFrame: CGRect?, duration: Double?) {
        guard let keyboardFrame,
              let duration else {
            return
        }

        // Convert keyboard frame to our coordinate system
        let convertedFrame = convert(keyboardFrame, from: nil)
        keyboardHeight = bounds.maxY - convertedFrame.minY

        // Adjust text view content inset instead of resizing
        UIView.animate(withDuration: duration) {
            self.updateContentInsets()
        }
    }

    private func handleKeyboardWillHide(duration: Double?) {
        guard let duration else {
            return
        }

        keyboardHeight = 0

        UIView.animate(withDuration: duration) {
            self.updateContentInsets()
        }
    }

    // MARK: - Content Inset Management

    internal func updateContentInsets() {
        // Adjust the text view's content inset to account for keyboard
        // This keeps the content scrollable without compressing the view
        let bottomInset = keyboardHeight > 0 ? keyboardHeight : 0

        let contentInsets = EdgeInsets(
            top: 0,
            left: 0,
            bottom: bottomInset,
            right: 0
        )

        // Only update if insets have actually changed to prevent unnecessary scroll jumps
        let newInsets = contentInsets.uiEdgeInsets
        if textView.contentInset != newInsets {
            // Save current scroll position
            let savedContentOffset = textView.contentOffset

            textView.contentInset = newInsets

            // Also adjust the scroll indicator insets
            textView.scrollIndicatorInsets = textView.contentInset

            // Restore scroll position if it changed
            if textView.contentOffset != savedContentOffset {
                textView.setContentOffset(savedContentOffset, animated: false)
            }
        }

        // Make sure the gutter redraws with proper positioning
        gutterView.setNeedsDisplay()

        // For iOS / iPadOS, also update gutter frame to match text view content insets
        layoutViews()  // Force layout update to sync gutter with text view

        // If keyboard is showing, ensure we can still scroll to see all content
        if keyboardHeight > 0 {
            // Adjust content size if needed to ensure full scrolling
            let minContentHeight = bounds.height - keyboardHeight + textView.contentSize.height
            if textView.contentSize.height < minContentHeight {
                textView.contentSize = CGSize(width: textView.contentSize.width, height: minContentHeight)
            }
        }
    }

    // MARK: - Cleanup

    internal func cleanupKeyboardObservers() {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
        keyboardObservers.removeAll()
    }
}
#endif
