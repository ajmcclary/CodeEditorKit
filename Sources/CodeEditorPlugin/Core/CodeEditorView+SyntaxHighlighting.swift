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
        Self.logger.debug("🎨 applySyntaxHighlighting called - enabled: \(self.isSyntaxHighlightingEnabled), language: \(self.language.name)")
        
        guard isSyntaxHighlightingEnabled else {
            Self.logger.debug("❌ Syntax highlighting disabled, cancelling")
            asyncHighlighter.cancelAllHighlighting()
            return
        }
        
        Self.logger.debug("✅ Scheduling syntax highlighting for language: \(self.language.name)")
        
        // Use async highlighting with debouncing
        asyncHighlighter.scheduleHighlighting(
            for: self,
            language: language,
            visibleRange: nil
        )
    }

    internal func applySyntaxHighlighting(in range: NSRange) {
        guard range.location != NSNotFound else {
            return
        }
        
        guard isSyntaxHighlightingEnabled else {
            return
        }
        
        // For range-based highlighting, schedule with visible range
        asyncHighlighter.scheduleHighlighting(
            for: self,
            language: language,
            visibleRange: range
        )
    }

    // MARK: - Mac Catalyst Support
    
    #if targetEnvironment(macCatalyst)
    /// Apply text color specifically for Mac Catalyst
    /// This ensures text is visible by applying color attributes to all text
    public func applyTextColorForMacCatalyst() {
        let textStorage = self.textStorage
        
        // Use current textColor if set, otherwise fallback to a guaranteed visible color
        // For Mac Catalyst, we need to ensure we have a proper, visible color
        let effectiveTextColor: PlatformColor
        if let currentColor = self.textColor {
            // Verify the current color is actually visible
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            if currentColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha),
               alpha > 0.1, (red + green + blue) > 0.1 {
                // Ensure full opacity for Mac Catalyst
                if alpha < 0.95 {
                    effectiveTextColor = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
                } else {
                    effectiveTextColor = currentColor
                }
            } else {
                // Current color is invisible, use fallback
                effectiveTextColor = PlatformColors.label
            }
        } else {
            // No color set, use guaranteed visible fallback
            effectiveTextColor = PlatformColors.label
        }
        
        let font = self.font ?? PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        
        Self.logger.debug("Mac Catalyst: Setting text color \(String(describing: effectiveTextColor)) of type \(String(describing: type(of: effectiveTextColor)))")
        Self.logger.debug("Mac Catalyst: Text storage length: \(textStorage.length)")
        Self.logger.debug("Mac Catalyst: Current text sample: \(String(describing: self.text?.prefix(50)))")
        
        // Apply to existing text with aggressive attribute application
        if textStorage.length > 0 {
            textStorage.beginEditing()
            
            // Remove ALL existing color-related attributes first
            textStorage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: textStorage.length))
            textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))
            
            // Add the new attributes with high priority
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: effectiveTextColor,
                .font: font,
                .backgroundColor: UIColor.clear  // Ensure background doesn't hide text
            ]
            
            textStorage.addAttributes(attributes, range: NSRange(location: 0, length: textStorage.length))
            textStorage.endEditing()
            
            Self.logger.debug("Mac Catalyst: Applied attributes to \(textStorage.length) characters")
        } else {
            Self.logger.debug("Mac Catalyst: No text content to apply color to")
        }
        
        // Update typing attributes for new text
        var typingAttrs = self.typingAttributes
        typingAttrs[.foregroundColor] = effectiveTextColor
        typingAttrs[.font] = font
        typingAttrs[.backgroundColor] = UIColor.clear
        self.typingAttributes = typingAttrs
        
        // Force comprehensive redraw
        self.setNeedsDisplay()
        self.setNeedsLayout()
        
        // Force layout manager to refresh
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let layoutManager = self.layoutManager {
            layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        }
        #else
        // On iOS/Mac Catalyst, layoutManager is not optional
        layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        #endif
        
        Self.logger.debug("Mac Catalyst: Applied text color to all text. TextColor: \(String(describing: effectiveTextColor)), Font: \(String(describing: font))")
    }
    #endif
}
