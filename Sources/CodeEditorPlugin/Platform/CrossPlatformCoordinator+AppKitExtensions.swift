#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import Foundation

// MARK: - MacOS Specific Implementation

extension CrossPlatformCoordinator {
    func optimizeForMacOS(_ textView: CodeEditorView) {
        // Enable platform-specific features
        // Note: CodeEditorView doesn't currently support multiple selection
        
        // Set up rulers and guides
        if let scrollView = textView.enclosingScrollView {
            scrollView.rulersVisible = false // Can be toggled by user
        }
    }
    
    func setupMacOSNotifications() {
        // Workspace notifications
        let workspaceObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.debug("Application activated")
        }
        addObserver(workspaceObserver)
    }
    
    func handleMacOSKeyInput(key: String, modifiers: PlatformModifierFlags, in textView: CodeEditorView) -> Bool {
        // Full keyboard shortcut support
        if modifiers.contains(.command) {
            switch key {
            case "d": selectNextOccurrence(in: textView); return true
            case "l": selectLine(in: textView); return true
            case "/": toggleComment(in: textView); return true
            default: break
            }
        }
        
        if modifiers.contains(.option) {
            switch key {
            case "↑": logger.debug("Move line up"); return true
            case "↓": logger.debug("Move line down"); return true
            default: break
            }
        }
        
        return false
    }
    
    func handleMacOSMouseInput(location: CGPoint, type: PlatformMouseEventType, in textView: CodeEditorView) -> Bool {
        switch type {
        case .rightClick:
            showContextMenu(at: location, in: textView)
            return true

        case .hover:
            // Show hover information
            logger.debug("Hover detected")
            return true

        default:
            return false
        }
    }
    
    func handleMacOSPencilInput(location: CGPoint, pressure: CGFloat, azimuth: CGFloat, in textView: CodeEditorView) -> Bool {
        // Apple Pencil not supported on macOS
        _ = location
        _ = pressure
        _ = azimuth
        _ = textView
        return false
    }
    
    // MARK: - MacOS Context Menu
    
    func createMacOSContextMenu(for textView: CodeEditorView, at _: CGPoint) -> NSMenu {
        let descriptor = SharedContextMenuBuilder.createStandardCodeEditorMenu(for: textView, coordinator: self)
        return SharedContextMenuBuilder.buildNSMenu(from: descriptor, target: self)
    }
    
    // MARK: - MacOS Specific Actions
    
    private func selectNextOccurrence(in textView: CodeEditorView) {
        guard let selectedRange = textView.selectedRanges.first?.rangeValue,
              selectedRange.length > 0,
              let selectedText = textView.text else { return }
        
        // swiftlint:disable:next legacy_objc_type
        let searchString = (selectedText as NSString).substring(with: selectedRange)
        let searchRange = NSRange(location: selectedRange.upperBound, length: selectedText.count - selectedRange.upperBound)
        
        // swiftlint:disable:next legacy_objc_type
        let nextRange = (selectedText as NSString).range(of: searchString, options: [], range: searchRange)
        if nextRange.location != NSNotFound {
            textView.selectedRange = nextRange
            textView.scrollRangeToVisible(nextRange)
        } else {
            // Search from beginning
            let wrapRange = NSRange(location: 0, length: selectedRange.location)
            // swiftlint:disable:next legacy_objc_type
            let nextRange = (selectedText as NSString).range(of: searchString, options: [], range: wrapRange)
            if nextRange.location != NSNotFound {
                textView.selectedRange = nextRange
                textView.scrollRangeToVisible(nextRange)
            }
        }
    }
    
    private func selectLine(in textView: CodeEditorView) {
        guard let text = textView.text else { return }
        let selectedRange = textView.selectedRange
        // swiftlint:disable:next legacy_objc_type
        let nsText = (text as NSString)
        
        // Find line boundaries
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        nsText.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: selectedRange)
        
        // Select the entire line
        let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        textView.selectedRange = lineRange
        textView.scrollRangeToVisible(lineRange)
    }
    
    func toggleComment(in textView: CodeEditorView) {
        guard let text = textView.text else { return }
        let language = textView.language
        
        let selectedRange = textView.selectedRange
        // swiftlint:disable:next legacy_objc_type
        let nsText = (text as NSString)
        
        // Get the comment syntax for the current language
        let commentPrefix = getCommentPrefix(for: language)
        
        // Find line boundaries for the selection
        var lineStart = 0
        var lineEnd = 0
        nsText.getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil, for: selectedRange)
        
        // Check if the line is already commented
        let lineText = nsText.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
        let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLine.hasPrefix(commentPrefix) {
            // Remove comment
            let uncommentedLine = lineText.replacingOccurrences(of: commentPrefix, with: "", options: .anchored)
            textView.insertText(uncommentedLine, replacementRange: NSRange(location: lineStart, length: lineEnd - lineStart))
        } else {
            // Add comment
            let commentedLine = commentPrefix + " " + lineText
            textView.insertText(commentedLine, replacementRange: NSRange(location: lineStart, length: lineEnd - lineStart))
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
    
    @objc private func toggleCommentAction() {
        // Find the first responder text view
        if let window = NSApp.keyWindow,
           let textView = window.firstResponder as? CodeEditorView {
            toggleComment(in: textView)
        }
    }
    
    @objc private func formatSelection() {
        logger.debug("Format selection requested")
        // Implementation tracked in GitHub issue #1
    }
    
    @objc private func goToDefinition() {
        logger.debug("Go to definition requested")
        // Implementation tracked in GitHub issue #2
    }
    
    @objc private func findReferences() {
        logger.debug("Find references requested")
        // Implementation tracked in GitHub issue #3
    }
}
#endif
