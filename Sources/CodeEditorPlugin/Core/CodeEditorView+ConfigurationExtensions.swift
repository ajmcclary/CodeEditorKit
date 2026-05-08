import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Configuration & Line Highlighting

extension CodeEditorView {
    // MARK: - Configuration Application

    internal func applyConfiguration() {
        // Apply performance settings first (including memory monitor)
        if let configMemoryMonitor = configuration.performance.memoryMonitor {
            memoryMonitor = configMemoryMonitor
        }

        // Apply workspace root for LSP
        #if canImport(AppKit)
        if lspManager.workspaceRoot != configuration.workspaceRoot {
            lspManager.workspaceRoot = configuration.workspaceRoot
        }
        #endif

        // Apply display settings
        #if canImport(AppKit)
        // On macOS, line numbers are handled by NSRulerView in the container
        // Always ensure no GutterView exists on the text view itself
        updateGutterVisibility()
        #else
        // On iOS/Catalyst, gutter is handled by the container view
        // But when used standalone, the text view should manage its own gutter
        updateGutterVisibility()
        #endif

        if configuration.display.isSelectedLineHighlighted {
            updateSelectedLineHighlight()
        } else {
            removeLineHighlight()
        }

        if configuration.display.isSyntaxHighlightingEnabled {
            applySyntaxHighlighting()
        } else {
            removeSyntaxHighlighting()
        }

        updateLayoutManagerSettings()

        // Apply font settings
        font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        textColor = PlatformColors.label

        // Apply layout settings
        #if canImport(AppKit)
        updateTextContainerSize()
        #endif

        // Apply paragraph style for tab width and line spacing
        applyParagraphStyle()

        // Apply word wrap settings (especially important on iOS when font size changes)
        ContainerViewHelper.configureTextViewScrolling(self, wrapLines: configuration.layout.wrapLines)

        // Update text container size for word wrap changes
        #if canImport(UIKit)
        updateTextContainerSize()
        #endif

        // Ensure text colors are visible on Mac Catalyst

        // Apply behavior settings
        isEditable = configuration.behavior.isEditable
        isSelectable = configuration.behavior.isSelectable

        // Apply text input behavior settings on macOS
        #if canImport(AppKit)
        isAutomaticTextCompletionEnabled = configuration.behavior.isAutomaticTextCompletionEnabled
        isAutomaticQuoteSubstitutionEnabled = configuration.behavior.isAutomaticQuoteSubstitutionEnabled
        isAutomaticDashSubstitutionEnabled = configuration.behavior.isAutomaticDashSubstitutionEnabled
        isAutomaticTextReplacementEnabled = configuration.behavior.isAutomaticTextReplacementEnabled
        isAutomaticSpellingCorrectionEnabled = configuration.behavior.isAutomaticSpellingCorrectionEnabled
        isGrammarCheckingEnabled = configuration.behavior.isGrammarCheckingEnabled
        isContinuousSpellCheckingEnabled = configuration.behavior.isContinuousSpellCheckingEnabled
        #endif

        // Update code folding configuration
        updateCodeFoldingConfiguration()
        updateRangeBasedHighlightingConfiguration()

        // Force layout update
        #if canImport(AppKit)
        needsLayout = true
        #else
        setNeedsLayout()
        #endif

        // Notify container view to update gutter width if needed
        containerView?.applyConfiguration()
    }

    // MARK: - Line Highlighting

    @objc
    internal func handleTextViewDidChangeSelection(_ notification: Notification) {
        updateSelectedLineHighlight()

        // Forward to delegate
        delegateProxy.textViewDidChangeSelection(notification)

        // Post our own notification
        let selectionNotification = Notification(name: Self.codeEditorViewDidChangeSelectionNotification, object: self)
        NotificationCenter.default.post(selectionNotification)

        // Publish selection changed event
        eventPublisher.publishSync(.textSelectionDidChange(selectedRange))
    }

    internal func updateSelectedLineHighlight() {
        guard isSelectedLineHighlightEnabled else {
            removeLineHighlight()
            return
        }

        createLineHighlightIfNeeded()
        updateLineHighlightFrame()
    }

    private func createLineHighlightIfNeeded() {
        guard lineHighlightView == nil else {
            return
        }

        let highlight = LineHighlightView()
        highlight.highlightColor = configuration.display.selectedLineHighlightColor

        // Add as background overlay
        #if canImport(AppKit)
        addSubview(highlight, positioned: .below, relativeTo: nil)
        #else
        addSubview(highlight)
        sendSubviewToBack(highlight)
        #endif
        lineHighlightView = highlight
    }

    private func removeLineHighlight() {
        lineHighlightView?.removeFromSuperview()
        lineHighlightView = nil
    }

    internal func updateLineHighlightFrame() {
        guard let highlightView = lineHighlightView else {
            return
        }

        let selectedRange = selectedRange
        guard selectedRange.location != NSNotFound else {
            return
        }

        // Get the line range for the selection
        #if canImport(AppKit)
        guard let range = Range(selectedRange, in: string) else { return }
        let stringLineRange = string.lineRange(for: range)
        let lineRange = NSRange(stringLineRange, in: string)
        #else
        guard let text = self.text,
              let range = Range(selectedRange, in: text) else { return }
        let stringLineRange = text.lineRange(for: range)
        let lineRange = NSRange(stringLineRange, in: text)
        #endif

        // Get the rect for the line using TextKit2-compatible approach
        guard let lineRect = calculateLineRect(for: lineRange) else {
            return
        }

        // Adjust frame
        var frame = lineRect
        frame.origin.x = 0
        frame.size.width = bounds.width
        // Don't add textContainerInset here - calculateLineRect already accounts for it

        highlightView.frame = frame
        if let lineHighlight = highlightView as? LineHighlightView {
            lineHighlight.highlightColor = configuration.display.selectedLineHighlightColor
        }
    }

    // MARK: - Layout Manager Settings

    private func updateLayoutManagerSettings() {
        #if canImport(AppKit)
        layoutManager?.showsInvisibleCharacters = isInvisibleCharactersEnabled
        #else
        // UITextView's layout manager doesn't support showsInvisibleCharacters directly
        // For Mac Catalyst, we need to implement custom rendering
        // This is a known limitation - invisible characters require custom drawing on iOS/Catalyst
        #endif
    }

    // MARK: - Syntax Highlighting Toggle

    internal func removeSyntaxHighlighting() {
        #if canImport(AppKit)
        guard let textStorage = self.textStorage else { return }
        #else
        let textStorage = self.textStorage
        #endif

        // Cancel any in-progress highlighting first
        asyncHighlighter.cancelAllHighlighting()

        // For large files, batch the attribute changes
        let textLength = textStorage.length
        guard textLength > 0 else { return }

        textStorage.beginEditing()
        defer { textStorage.endEditing() }

        // Process in chunks for better performance on large files
        let chunkSize = configuration.performance.maxSyntaxHighlightingLength > 0
            ? min(configuration.performance.maxSyntaxHighlightingLength, 50_000)
            : 50_000

        let defaultColor = textColor ?? PlatformColors.label

        if textLength <= chunkSize {
            // Small file - process in one go
            let fullRange = NSRange(location: 0, length: textLength)
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.addAttribute(.foregroundColor, value: defaultColor, range: fullRange)
        } else {
            // Large file - process in chunks to avoid blocking
            var location = 0
            while location < textLength {
                autoreleasepool {
                    let remainingLength = textLength - location
                    let currentChunkSize = min(chunkSize, remainingLength)
                    let range = NSRange(location: location, length: currentChunkSize)

                    textStorage.removeAttribute(.foregroundColor, range: range)
                    textStorage.addAttribute(.foregroundColor, value: defaultColor, range: range)

                    location += currentChunkSize
                }
            }
        }
    }

    // MARK: - Code Folding Configuration

    /// Update code folding configuration from EditorConfiguration
    internal func updateCodeFoldingConfiguration() {
        codeFoldingEngine.configuration = configuration.createCodeFoldingConfiguration()

        // Update folding regions if folding is enabled
        if configuration.display.isCodeFoldingEnabled {
            // Update the folding engine with current language
            codeFoldingEngine.attach(to: self)
        }
    }
}
