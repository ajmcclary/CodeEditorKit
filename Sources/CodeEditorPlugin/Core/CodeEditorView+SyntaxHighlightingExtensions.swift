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
            Task { @MainActor [weak self] in
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
        
        // On Mac Catalyst, ensure text remains visible after edits
        #if targetEnvironment(macCatalyst)
        if textStorage.length > 0 && textStorage.editedMask.contains(.editedCharacters) {
            // Apply base text color to ensure visibility
            let baseColor = textColor ?? PlatformColors.label
            textStorage.addAttribute(.foregroundColor, value: baseColor, range: textStorage.editedRange)
        }
        #endif
        
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
        let syntaxService = businessLogicServices.syntaxHighlightingService
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
        
        // Only update configuration if it actually changed to prevent feedback loops
        if configuration != updatedConfig {
            configuration = updatedConfig
        }
        
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
        let syntaxService = businessLogicServices.syntaxHighlightingService
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
        let syntaxService = businessLogicServices.syntaxHighlightingService
        let textStorage = self.textStorage
        
        // Get the text view's setup result to check TextKit version
        let setupResult = TextKitSetupHelper.setupTextKit(for: self)
        let isUsingTextKit1 = !setupResult.isUsingTextKit2
        
        let attributes = syntaxService.createCatalystTextAttributes(
            textColor: self.textColor,
            font: self.font,
            configuration: configuration
        )
        
        Self.logger.debug("Mac Catalyst: Text storage length: \(textStorage.length)")
        Self.logger.debug("Mac Catalyst: Current text sample: \(String(describing: self.text?.prefix(50)))")
        Self.logger.debug("Mac Catalyst: Using TextKit\(isUsingTextKit1 ? "1" : "2")")
        
        // Apply to existing text with aggressive attribute application
        if textStorage.length > 0 {
            textStorage.beginEditing()
            
            // For TextKit1 on Mac Catalyst, we need a different approach
            if isUsingTextKit1 {
                // First, ensure we have a visible base color
                let baseColor = PlatformColors.label.resolvedColor(with: self.traitCollection)
                
                // Apply attributes more aggressively for TextKit1
                let fullRange = NSRange(location: 0, length: textStorage.length)
                
                // Remove existing attributes that might interfere
                textStorage.removeAttribute(.foregroundColor, range: fullRange)
                textStorage.removeAttribute(.backgroundColor, range: fullRange)
                
                // Apply font first - this is critical for TextKit1
                if let font = self.font {
                    textStorage.addAttribute(.font, value: font, range: fullRange)
                }
                
                // Apply color with resolved value
                textStorage.addAttribute(.foregroundColor, value: baseColor, range: fullRange)
                
                // If syntax highlighting is enabled, re-apply it
                if configuration.display.enableSyntaxHighlighting {
                    // This will trigger the async highlighter to apply token colors
                    applySyntaxHighlighting()
                }
            } else {
                // TextKit2 path - use the standard approach
                textStorage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: textStorage.length))
                textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))
                textStorage.addAttributes(attributes, range: NSRange(location: 0, length: textStorage.length))
            }
            
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
        
        // For TextKit1, we need more aggressive invalidation
        if isUsingTextKit1 {
            // Access layoutManager is OK here since we're already in TextKit1 mode
            // On Mac Catalyst, layoutManager is not optional
            self.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        }
        
        // Force text redraw by invalidating intrinsic content size
        self.invalidateIntrinsicContentSize()
        
        // Additional force refresh for Mac Catalyst
        if let superview = self.superview {
            superview.setNeedsLayout()
        }
        
        Self.logger.debug("Mac Catalyst: Applied text color to all text.")
    }
    #endif
}
