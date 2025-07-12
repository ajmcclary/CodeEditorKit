#if canImport(UIKit)
import Foundation
import UIKit

// MARK: - IOS Specific Implementation

extension CrossPlatformCoordinator {
    func optimizeForIOS(_ textView: CodeEditorView) {
        // Store weak reference for toolbar actions
        self.associatedTextView = textView
        
        // Configure for touch
        textView.isSelectable = true
        textView.isEditable = true
        
        // Adjust content insets for safe area
        if let window = textView.window {
            let safeArea = window.safeAreaInsets
            let insets = EdgeInsets(
                top: safeArea.top + 8,
                left: 0,
                bottom: safeArea.bottom + 8,
                right: 0
            )
            textView.setUnifiedTextContainerInsets(insets)
        }
        
        // Configure keyboard
        textView.keyboardType = .default
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        
        // Add input accessory view for iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            textView.inputAccessoryView = createInputAccessoryView()
        }
    }
    
    func createInputAccessoryView() -> UIView {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let items = [
            UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: self, action: #selector(undo)),
            UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: self, action: #selector(redo)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .plain, target: self, action: #selector(find)),
            UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), style: .plain, target: self, action: #selector(dismissKeyboard))
        ]
        
        toolbar.items = items
        return toolbar
    }
    
    func setupIOSNotifications() {
        // Keyboard notifications
        let keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract values outside the Task to avoid actor isolation issues
            let keyboardInfo = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            
            Task { @MainActor in
                self?.handleKeyboardWillShow(keyboardInfo: keyboardInfo, duration: duration)
            }
        }
        addObserver(keyboardObserver)
        
        // Orientation change notifications
        let orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.orientationDidChange()
            }
        }
        addObserver(orientationObserver)
    }
    
    func handleIOSKeyInput(key: String, modifiers: PlatformModifierFlags, in textView: CodeEditorView) -> Bool {
        // Limited keyboard support on iOS
        if isExternalKeyboardConnected() && modifiers.contains(.command) {
            switch key {
            case "f": showFind(in: textView); return true
            case "z": textView.undoManager?.undo(); return true
            default: break
            }
        }
        return false
    }
    
    func handleIOSTouchInput(touches: Set<AnyHashable>, phase: PlatformTouchPhase, in textView: CodeEditorView) -> Bool {
        // Handle multi-touch gestures
        if touches.count == 2 {
            // Two-finger tap for context menu
            if phase == .ended {
                showContextMenu(in: textView)
                return true
            }
        }
        return false
    }
    
    func handleIOSMouseInput(location: CGPoint, type: PlatformMouseEventType, in textView: CodeEditorView) -> Bool {
        // Limited mouse support on iOS
        if isPointingDeviceConnected() {
            switch type {
            case .rightClick:
                showContextMenu(at: location, in: textView)
                return true
                
            default:
                return false
            }
        }
        return false
    }
    
    func handleIOSPencilInput(location: CGPoint, pressure: CGFloat, azimuth _: CGFloat, in textView: CodeEditorView) -> Bool {
        // Handle Apple Pencil input
        if pressure > 0.5 {
            // Heavy pressure for selection
            startSelection(at: location, in: textView)
            return true
        }
        return false
    }
    
    // MARK: - IOS Context Menu
    
    func createIOSContextMenu(for textView: CodeEditorView, at _: CGPoint) -> UIMenu {
        let descriptor = SharedContextMenuBuilder.createStandardCodeEditorMenu(for: textView, coordinator: self)
        return SharedContextMenuBuilder.buildUIMenu(from: descriptor)
    }
    
    // MARK: - IOS Keyboard Management
    
    @MainActor
    private func handleKeyboardWillShow(keyboardInfo: CGRect?, duration: Double?) {
        guard keyboardInfo != nil,
              let duration else {
            return
        }
        
        // Update keyboard height
        logger.debug("Keyboard shown")
        
        // Animate adjustment
        UIView.animate(withDuration: duration) {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - IOS Specific Helpers
    
    func isExternalKeyboardConnected() -> Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        // Check for external keyboard by examining the input view controller
        // When an external keyboard is connected, the software keyboard is typically hidden
        // Note: firstResponder is not available on UIWindow in newer iOS versions
        // For now, assume no external keyboard on iOS simulator/device
        return false
        #endif
    }
    
    // MARK: - IOS Gesture Setup
    
    func setupIOSGestures(for textView: CodeEditorView) {
        // Long press for context menu
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressUIKit(_:)))
        textView.addGestureRecognizer(longPress)
        
        // Two-finger tap for quick actions
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        textView.addGestureRecognizer(twoFingerTap)
    }
    
    @objc private func handleLongPressUIKit(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let textView = gesture.view as? CodeEditorView else { return }
        
        let location = gesture.location(in: textView)
        showContextMenu(at: location, in: textView)
    }
    
    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.view is CodeEditorView else { return }
        logger.debug("Two-finger tap detected")
        // Could trigger quick actions menu
    }
    
    // MARK: - IOS Device Detection
    
    func isPointingDeviceConnected() -> Bool {
        // Check if mouse/trackpad is connected
        if #available(iOS 13.4, *) {
            return UIDevice.current.userInterfaceIdiom == .pad
        }
        return false
    }
    
    private func keyboardDidConnect() {
        adjustFeaturesForPlatform()
    }
    
    internal func orientationDidChange() {
        // Adjust UI for new orientation
        let orientation = UIDevice.current.orientation
        
        // Update platform adjustments based on orientation
        if orientation.isLandscape {
            // In landscape, recreate adjustments with appropriate touch target size
            platformAdjustments = PlatformAdjustments(
                defaultFontSize: platformAdjustments.defaultFontSize,
                lineSpacing: platformAdjustments.lineSpacing,
                gutterWidth: platformAdjustments.gutterWidth,
                minimumTouchTargetSize: 40,
                maxFileSize: platformAdjustments.maxFileSize,
                maxHighlightingLength: platformAdjustments.maxHighlightingLength,
                showMinimap: platformAdjustments.showMinimap,
                enableMultiCursor: platformAdjustments.enableMultiCursor
            )
        } else {
            // Portrait uses standard iOS touch target size
            platformAdjustments = PlatformAdjustments(
                defaultFontSize: platformAdjustments.defaultFontSize,
                lineSpacing: platformAdjustments.lineSpacing,
                gutterWidth: platformAdjustments.gutterWidth,
                minimumTouchTargetSize: 44,
                maxFileSize: platformAdjustments.maxFileSize,
                maxHighlightingLength: platformAdjustments.maxHighlightingLength,
                showMinimap: platformAdjustments.showMinimap,
                enableMultiCursor: platformAdjustments.enableMultiCursor
            )
        }
        
        // Notify observers of the change
        objectWillChange.send()
    }
    
    // MARK: - IOS Toolbar Actions
    
    @objc private func undo() {
        guard let textView = associatedTextView else {
            logger.warning("No associated text view for undo action")
            return
        }
        textView.undoManager?.undo()
    }
    
    @objc private func redo() {
        guard let textView = associatedTextView else {
            logger.warning("No associated text view for redo action")
            return
        }
        textView.undoManager?.redo()
    }
    
    @objc private func find() {
        guard let textView = associatedTextView else {
            logger.warning("No associated text view for find action")
            return
        }
        showFind(in: textView)
    }
    
    private func showFind(in textView: CodeEditorView) {
        // Create a simple find interface
        let alert = UIAlertController(title: "Find", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Search text..."
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        
        let findAction = UIAlertAction(title: "Find", style: .default) { [weak alert] _ in
            if let searchText = alert?.textFields?.first?.text,
               !searchText.isEmpty {
                self.findText(searchText, in: textView)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(findAction)
        alert.addAction(cancelAction)
        
        if let viewController = textView.window?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }
    
    private func findText(_ searchText: String, in textView: CodeEditorView) {
        guard let text = textView.text else { return }
        
        let searchRange = NSRange(location: textView.selectedRange.upperBound, length: text.count - textView.selectedRange.upperBound)
        
        // swiftlint:disable:next legacy_objc_type
        let foundRange = (text as NSString).range(of: searchText, options: .caseInsensitive, range: searchRange)
        if foundRange.location != NSNotFound {
            textView.selectedRange = foundRange
            textView.scrollRangeToVisible(foundRange)
        } else {
            // Search from beginning
            let wrapRange = NSRange(location: 0, length: textView.selectedRange.location)
            // swiftlint:disable:next legacy_objc_type
            let foundRange = (text as NSString).range(of: searchText, options: .caseInsensitive, range: wrapRange)
            if foundRange.location != NSNotFound {
                textView.selectedRange = foundRange
                textView.scrollRangeToVisible(foundRange)
            }
        }
    }
    
    func toggleComment(in textView: CodeEditorView) {
        guard let text = textView.text else { return }
        let language = textView.language
        
        let selectedRange = textView.selectedRange
        
        // Get the comment syntax for the current language
        let commentPrefix = getCommentPrefix(for: language)
        
        // Find line boundaries for the selection
        var lineStart = 0
        var lineEnd = 0
        // swiftlint:disable:next legacy_objc_type
        (text as NSString).getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil, for: selectedRange)
        
        // Check if the line is already commented
        // swiftlint:disable:next legacy_objc_type
        let lineText = (text as NSString).substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
        let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLine.hasPrefix(commentPrefix) {
            // Remove comment
            let uncommentedLine = lineText.replacingOccurrences(of: commentPrefix, with: "", options: .anchored)
            if textView.responds(to: #selector(UITextView.insertText(_:))) {
                textView.selectedRange = NSRange(location: lineStart, length: lineEnd - lineStart)
                textView.insertText(uncommentedLine)
            }
        } else {
            // Add comment
            let commentedLine = commentPrefix + " " + lineText
            if textView.responds(to: #selector(UITextView.insertText(_:))) {
                textView.selectedRange = NSRange(location: lineStart, length: lineEnd - lineStart)
                textView.insertText(commentedLine)
            }
        }
    }
    
    private func getCommentPrefix(for language: Language) -> String {
        switch language {
        case .swift, .javascript, .typescript, .java, .c, .cpp, .go, .rust, .php:
            return "//"

        case .python, .ruby, .shell, .yaml:
            return "#"

        case .html, .xml:
            return "<!--"

        case .css:
            return "/*"

        case .sql:
            return "--"

        case .markdown, .json, .plainText:
            return "//" // Default fallback
        }
    }
}
#endif
