import Foundation
import os.log

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
            eventPublisher.publish(.textDidChange(string))
            #else
            eventPublisher.publish(.textDidChange(text ?? ""))
            #endif
            
            // Check for completion triggering
            if isCompletionEnabled {
                checkForCompletionTrigger(at: editedRange)
            }
            
            // LSP document context can be updated here when integrated
            // updateLSPDocumentContext()
        }
    }

    // MARK: - Apply Highlighting
    
    internal func applySyntaxHighlighting() {
        kLogger.debug("🎨 applySyntaxHighlighting called - enabled: \(self.isSyntaxHighlightingEnabled), language: \(self.language.name)")
        
        guard isSyntaxHighlightingEnabled else {
            kLogger.debug("❌ Syntax highlighting disabled, cancelling")
            asyncHighlighter.cancelAllHighlighting()
            return
        }
        
        kLogger.debug("✅ Scheduling syntax highlighting for language: \(self.language.name)")
        
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

    // MARK: - Remove Highlighting
    
    private func removeSyntaxHighlighting() {
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

    // MARK: - Mac Catalyst Support
    
    #if targetEnvironment(macCatalyst)
    /// Apply text color specifically for Mac Catalyst
    /// This ensures text is visible by applying color attributes to all text
    internal func applyTextColorForMacCatalyst() {
        let textStorage = self.textStorage
        
        // Use platform abstraction for text color
        let textColor = self.textColor ?? PlatformColors.label
        let font = self.font ?? PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        
        kLogger.debug("Mac Catalyst: Setting text color \(String(describing: textColor)) of type \(String(describing: type(of: textColor)))")
        
        // Apply to existing text
        if textStorage.length > 0 {
            textStorage.beginEditing()
            textStorage.addAttributes([
                .foregroundColor: textColor,
                .font: font
            ], range: NSRange(location: 0, length: textStorage.length))
            textStorage.endEditing()
        }
        
        // Update typing attributes
        var typingAttrs = self.typingAttributes
        typingAttrs[.foregroundColor] = textColor
        typingAttrs[.font] = font
        self.typingAttributes = typingAttrs
        
        // Force the text view to redraw on Mac Catalyst
        self.setNeedsDisplay()
        
        kLogger.debug("Mac Catalyst: Applied text color to all text. TextColor: \(String(describing: textColor)), Font: \(String(describing: font))")
    }
    #endif
}
