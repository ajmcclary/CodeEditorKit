import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Syntax Highlighting

extension CodeEditorView {
    // MARK: - Notification Handlers
    
    @objc
    internal func handleTextStorageDidProcessEditing(_ notification: Notification) {
        guard let textStorage = notification.object as? NSTextStorage,
              textStorage === self.textStorage
        else {
            return
        }

        // Invalidate line index cache when text changes
        lineIndexCache.invalidate()
        
        // Pre-warm cache for visible content if this is a significant text change
        // Defer the pre-warming to avoid conflicts with text storage editing
        if textStorage.editedMask.contains(.editedCharacters) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                // For macOS, use visible rect to determine character range
                if let layoutManager = self.layoutManager,
                   let textContainer = self.textContainer,
                   let textStorage = self.textStorage {
                    let glyphRange = layoutManager.glyphRange(forBoundingRect: self.visibleRect, in: textContainer)
                    let visibleNSRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                    self.lineIndexCache.preWarmCache(for: textStorage.string, visibleRange: visibleNSRange)
                }
                #else
                let visibleNSRange = NSRange(location: 0, length: min(1_000, self.textStorage.length))
                self.lineIndexCache.preWarmCache(for: self.textStorage.string, visibleRange: visibleNSRange)
                #endif
            }
        }

        // Update gutter when text changes
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        gutterViewStorage?.needsDisplay = true
        #else
        gutterViewStorage?.setNeedsDisplay()
        #endif

        // Apply syntax highlighting to the edited range if enabled
        if configuration.display.enableSyntaxHighlighting {
            let editedRange = textStorage.editedRange
            if editedRange.location != NSNotFound {
                applySyntaxHighlighting(in: editedRange)
            }
        }
        
        // Publish text changed event
        let editedRange = textStorage.editedRange
        if editedRange.location != NSNotFound {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            eventPublisher.publishSync(.textDidChange(string))
            #else
            eventPublisher.publishSync(.textDidChange(text ?? ""))
            #endif
            
            // Check for completion triggering
            if isCodeCompletionEnabled {
                checkForCompletionTrigger(at: editedRange)
            }
            
            // LSP document context can be updated here when integrated
            // updateLSPDocumentContext()
        }
    }

    // MARK: - Apply Highlighting
    
    internal func applySyntaxHighlighting() {
        let syntaxService = BusinessLogic.syntaxHighlighting
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textLength = textStorage?.length ?? 0
        #else
        let textLength = textStorage.length
        #endif
        
        // Update adaptive performance mode based on file size
        adaptivePerformanceMode.updateMode(for: textLength, language: language)
        
        // Apply adaptive performance configuration, but preserve explicit user settings
        var updatedConfig = configuration
        
        // Store user preferences before adaptive mode overwrites them
        let userLineNumbersSetting = configuration.display.isLineNumbersEnabled
        let userCodeFoldingSetting = configuration.display.enableCodeFolding
        let userSyntaxHighlightingSetting = configuration.display.enableSyntaxHighlighting
        
        adaptivePerformanceMode.applyConfiguration(to: &updatedConfig)
        
        // Restore user-specified settings - adaptive mode should not override explicit user choices
        // Only apply adaptive performance to performance-related settings, not UI preferences
        updatedConfig.display.isLineNumbersEnabled = userLineNumbersSetting
        updatedConfig.display.enableCodeFolding = userCodeFoldingSetting
        updatedConfig.display.enableSyntaxHighlighting = userSyntaxHighlightingSetting
        
        configuration = updatedConfig
        
        guard syntaxService.shouldApplySyntaxHighlighting(
            isEnabled: isSyntaxHighlightingEnabled,
            textLength: textLength,
            maxLength: configuration.performance.maxSyntaxHighlightingLength
        ) else {
            syntaxService.cancelHighlighting(asyncHighlighter: asyncHighlighter)
            return
        }
        
        syntaxService.scheduleHighlighting(
            asyncHighlighter: asyncHighlighter,
            textView: self,
            language: language,
            visibleRange: nil
        )
    }

    internal func applySyntaxHighlighting(in range: NSRange) {
        let syntaxService = BusinessLogic.syntaxHighlighting
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textLength = textStorage?.length ?? 0
        #else
        let textLength = textStorage.length
        #endif
        
        guard syntaxService.isValidHighlightingRange(range, textLength: textLength) else {
            return
        }
        
        guard syntaxService.shouldApplySyntaxHighlighting(
            isEnabled: isSyntaxHighlightingEnabled,
            textLength: textLength,
            maxLength: configuration.performance.maxSyntaxHighlightingLength
        ) else {
            return
        }
        
        syntaxService.scheduleHighlighting(
            asyncHighlighter: asyncHighlighter,
            textView: self,
            language: language,
            visibleRange: range
        )
    }

    // MARK: - Mac Catalyst Support
    
    #if targetEnvironment(macCatalyst)
    /// Apply text color specifically for Mac Catalyst
    /// This ensures text is visible by applying color attributes to all text
    public func applyTextColorForMacCatalyst() {
        let syntaxService = BusinessLogic.syntaxHighlighting
        let textStorage = self.textStorage
        
        let attributes = syntaxService.createCatalystTextAttributes(
            textColor: self.textColor,
            font: self.font,
            configuration: configuration
        )
        
        Self.logger.debug("Mac Catalyst: Text storage length: \(textStorage.length)")
        Self.logger.debug("Mac Catalyst: Current text sample: \(String(describing: self.text?.prefix(50)))")
        
        // Apply to existing text with aggressive attribute application
        if textStorage.length > 0 {
            textStorage.beginEditing()
            
            // Remove ALL existing color-related attributes first
            textStorage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: textStorage.length))
            textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))
            
            // Add the new attributes with high priority
            textStorage.addAttributes(attributes, range: NSRange(location: 0, length: textStorage.length))
            textStorage.endEditing()
            
            Self.logger.debug("Mac Catalyst: Applied attributes to \(textStorage.length) characters")
        } else {
            Self.logger.debug("Mac Catalyst: No text content to apply color to")
        }
        
        // Update typing attributes for new text
        self.typingAttributes = attributes
        
        // Force comprehensive redraw
        self.setNeedsDisplay()
        self.setNeedsLayout()
        
        // Force layout manager to refresh
        layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        
        Self.logger.debug("Mac Catalyst: Applied text color to all text.")
    }
    #endif
}
