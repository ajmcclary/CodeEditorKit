import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Code Completion

extension CodeEditorView {
    // MARK: - Completion Triggering

    /// Check if completion should be triggered after text editing
    internal func checkForCompletionTrigger(at editedRange: NSRange) {
        guard isCodeCompletionEnabled,
              editedRange.length <= 1 // Only trigger on single character insertion
        else {
            return
        }

        // Get current cursor position
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let cursorPosition = selectedRange.location
        let text = string
        #else
        let cursorPosition = selectedRange.location
        let text = self.text ?? ""
        #endif

        // Check if we just typed a trigger character
        if cursorPosition > 0 && cursorPosition <= text.count {
            let index = text.index(text.startIndex, offsetBy: cursorPosition - 1)
            let typedChar = text[index]

            if completionTriggerCharacters.contains(typedChar) {
                // Trigger completion with character trigger
                requestCompletion(triggerKind: .character, triggerCharacter: String(typedChar))
            }
        }
    }

    // MARK: - Request Completion

    /// Request code completion at the current cursor position
    /// Requests code completion at the current cursor position.
    ///
    /// This method triggers the code completion system to provide suggestions based on the
    /// current context, language, and registered completion providers.
    ///
    /// - Parameters:
    ///   - triggerKind: The kind of trigger that initiated the completion request
    ///   - triggerCharacter: The character that triggered completion (if applicable)
    ///
    /// ## Trigger Kinds
    ///
    /// - `.manual`: User explicitly requested completion (e.g., Ctrl+Space)
    /// - `.automatic`: Triggered by typing a trigger character
    /// - `.incomplete`: Previous completion list was incomplete
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Manual completion request
    /// editor.requestCompletion(triggerKind: .manual)
    /// 
    /// // Automatic completion after typing '.'
    /// editor.requestCompletion(triggerKind: .automatic, triggerCharacter: ".")
    /// ```
    ///
    /// - Note: Completion must be enabled via `isCodeCompletionEnabled` or configuration
    ///
    /// - SeeAlso: `hideCompletionPopup()`, `isCodeCompletionEnabled`, `CompletionProvider`
    public func requestCompletion(triggerKind: CompletionTriggerKind = .manual, triggerCharacter: String? = nil) {
        guard isCodeCompletionEnabled else { return }

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let cursorPosition = selectedRange.location
        let text = string
        #else
        let cursorPosition = selectedRange.location
        let text = self.text ?? ""
        #endif

        // Extract current line text
        let lineRange = currentLineRange(at: cursorPosition)
        let lineText = String(text[lineRange])

        // Create completion context
        let context = CompletionContextModel(
            text: text,
            cursorPosition: cursorPosition,
            language: language,
            triggerKind: triggerKind,
            triggerCharacter: triggerCharacter,
            lineText: lineText,
            wordRange: currentWordRange(at: cursorPosition)
        )

        // Request completions asynchronously
        Task { @MainActor in
            do {
                let result = try await completionManager.requestCompletions(for: context)
                if !result.items.isEmpty {
                    showCompletionPopup(with: result.items, at: cursorPosition)
                }
            } catch {
                Self.logger.error("Completion request failed: \(error)")
            }
        }
    }

    // MARK: - Show Completion Popup

    /// Show completion popup with the given items
    private func showCompletionPopup(with items: [CompletionItemModel], at position: Int) {
        // Cancel any existing completion
        hideCompletionPopup()

        // Get completion view controller from delegate or create default
        let completionVC = textDelegate?.textViewCompletionViewController(self) ?? CompletionViewController()

        // Set up completion view controller
        completionViewController = completionVC
        if let modernVC = completionVC as? CompletionViewController {
            modernVC.completionItems = items
            modernVC.delegate = self
        } else {
            // Handle legacy completion view controllers
            // Modern completion items need to be set through the protocol
        }

        // Position and show completion popup
        let cursorRect = cursorRectForPosition(position)
        showCompletionWindow(with: completionVC, at: cursorRect)

        isCompletionActive = true
    }

    /// Get cursor rectangle for positioning completion popup
    private func cursorRectForPosition(_ position: Int) -> CGRect {
        let textKitBridge = TextKitBridge(textView: self)
        return textKitBridge.cursorRect(at: position) ?? CGRect(x: 0, y: 0, width: 1, height: 16)
    }

    /// Show completion window/popover at the specified rectangle
    private func showCompletionWindow(with viewController: any CompletionViewControllerRepresentable, at rect: CGRect) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Create completion window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = viewController as PlatformViewController
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = PlatformColors.clear
        window.hasShadow = true

        // Position window relative to text view
        if let textWindow = self.window {
            let screenRect = textWindow.convertToScreen(convert(rect, to: nil))
            let windowRect = NSRect(
                x: screenRect.origin.x,
                y: screenRect.origin.y - 200, // Show below cursor
                width: 300,
                height: 200
            )
            window.setFrame(windowRect, display: true)
        }

        completionWindow = window
        window.orderFront(nil)

        // Announce code completion availability
        announceChange("Code completion suggestions available")
        #else
        // iOS popover presentation
        guard let presentingVC = findViewController() else { return }

        let popoverVC = viewController
        popoverVC.modalPresentationStyle = .popover

        if let popover = popoverVC.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = rect
            popover.permittedArrowDirections = [.up, .down]
        }

        completionPopover = popoverVC
        presentingVC.present(popoverVC, animated: true)

        // Announce code completion availability
        announceChange("Code completion suggestions available")
        #endif
    }

    // MARK: - Hide Completion

    /// Hide the completion popup
    /// Dismisses the currently visible completion popup.
    ///
    /// Use this method to programmatically hide the completion suggestions popup.
    /// The popup is also automatically hidden when the user presses Escape, clicks
    /// outside, or performs other dismissal actions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Hide completion when losing focus
    /// func textViewDidResignFirstResponder() {
    ///     editor.hideCompletionPopup()
    /// }
    /// 
    /// // Hide on specific key press
    /// if event.keyCode == kVK_Escape {
    ///     editor.hideCompletionPopup()
    /// }
    /// ```
    ///
    /// - SeeAlso: `requestCompletion(triggerKind:triggerCharacter:)`
    public func hideCompletionPopup() {
        guard isCompletionActive else { return }

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        completionWindow?.close()
        completionWindow = nil
        #else
        completionPopover?.dismiss(animated: true)
        completionPopover = nil
        #endif

        completionViewController = nil
        isCompletionActive = false

        // Announce completion dismissal
        announceChange("Code completion dismissed")
    }

    // MARK: - Keyboard Handling

    /// Handle keyboard input for completion navigation
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func keyDown(with event: NSEvent) {
        // Handle completion navigation
        if isCompletionActive, let completionVC = completionViewController {
            switch event.keyCode {
            case 125: // Down arrow
                if let modernVC = completionVC as? CompletionViewController {
                    modernVC.selectNext()
                    return
                }

            case 126: // Up arrow
                if let modernVC = completionVC as? CompletionViewController {
                    modernVC.selectPrevious()
                    return
                }

            case 36: // Return
                if let modernVC = completionVC as? CompletionViewController {
                    modernVC.insertSelectedItem()
                    return
                }

            case 53: // Escape
                hideCompletionPopup()
                return

            default:
                break
            }
        }

        super.keyDown(with: event)
    }
    #endif

    // MARK: - Helper Methods

    /// Get current line range at position
    private func currentLineRange(at position: Int) -> Range<String.Index> {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let text = string
        #else
        let text = self.text ?? ""
        #endif

        let pos = min(position, text.count)
        let textIndex = text.index(text.startIndex, offsetBy: pos)
        return text.lineRange(for: textIndex..<textIndex)
    }

    /// Get current word range at position
    private func currentWordRange(at position: Int) -> NSRange? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let text = string
        #else
        let text = self.text ?? ""
        #endif

        guard position <= text.count else { return nil }

        let textIndex = text.index(text.startIndex, offsetBy: position)
        let wordRange = text.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted, options: .backwards, range: text.startIndex..<textIndex)

        if let range = wordRange {
            let start = text.distance(from: text.startIndex, to: range.upperBound)
            let end = position
            return NSRange(location: start, length: end - start)
        }

        return nil
    }

    #if canImport(UIKit)
    /// Find the presenting view controller for iOS popover
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
    #endif
}
