import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        
        // Apply display settings
        if configuration.display.showLineNumbers {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            updateGutterVisibility()
            #endif
        } else {
            removeGutter()
        }
        
        if configuration.display.highlightSelectedLine {
            updateSelectedLineHighlight()
        } else {
            removeLineHighlight()
        }
        
        if configuration.display.enableSyntaxHighlighting {
            applySyntaxHighlighting()
        } else {
            removeSyntaxHighlighting()
        }
        
        updateLayoutManagerSettings()
        
        // Apply font settings
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        textColor = PlatformColors.label
        #else
        font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        textColor = PlatformColors.label
        #endif
        
        // Apply layout settings
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if configuration.layout.wrapLines {
            textContainer?.widthTracksTextView = true
            isHorizontallyResizable = false
        } else {
            textContainer?.widthTracksTextView = false
            isHorizontallyResizable = true
        }
        #endif
        
        // Apply paragraph style for tab width and line spacing
        applyParagraphStyle()
        
        // Apply behavior settings
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        isEditable = configuration.behavior.isEditable
        isSelectable = configuration.behavior.isSelectable
        #else
        isEditable = configuration.behavior.isEditable
        isSelectable = configuration.behavior.isSelectable
        #endif
        
        // Update code folding configuration
        updateCodeFoldingConfiguration()
        
        // Force layout update
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        eventPublisher.publish(.textSelectionDidChange(selectedRange))
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

        let highlight = PlatformView()
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        highlight.wantsLayer = true
        highlight.layer?.backgroundColor = configuration.display.selectedLineHighlightColor.cgColor
        #else
        highlight.layer.backgroundColor = configuration.display.selectedLineHighlightColor.cgColor
        #endif

        // Add as background overlay
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let selectedRange = selectedRange
        #else
        let selectedRange = selectedRange
        #endif
        guard selectedRange.location != NSNotFound else {
            return
        }

        // Get the line range for the selection
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        highlightView.layer?.backgroundColor = configuration.display.selectedLineHighlightColor.cgColor
        #else
        highlightView.layer.backgroundColor = configuration.display.selectedLineHighlightColor.cgColor
        #endif
    }

    // MARK: - Layout Manager Settings

    private func updateLayoutManagerSettings() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        layoutManager?.showsInvisibleCharacters = isInvisibleCharactersEnabled
        #else
        // UITextView's layout manager doesn't support showsInvisibleCharacters
        #endif
    }
    
    // MARK: - Syntax Highlighting Toggle
    
    internal func removeSyntaxHighlighting() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage = self.textStorage else { return }
        #else
        let textStorage = self.textStorage
        #endif

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.foregroundColor, range: fullRange)

        // Restore default text color
        textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColors.label, range: fullRange)
    }
    
    // MARK: - Code Folding Configuration
    
    /// Update code folding configuration from EditorConfiguration
    internal func updateCodeFoldingConfiguration() {
        codeFoldingEngine.configuration = configuration.createCodeFoldingConfiguration()
        
        // Update folding regions if folding is enabled
        if configuration.display.enableCodeFolding {
            // Update the folding engine with current language
            codeFoldingEngine.attach(to: self)
        }
    }
}
