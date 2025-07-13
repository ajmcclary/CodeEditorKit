import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - TextKit & Text Management

extension CodeEditorView {
    // MARK: - Text Changes
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)

        // Update syntax highlighting for the affected area
        if isSyntaxHighlightingEnabled {
            let range = replacementRange.location != NSNotFound ? replacementRange : selectedRange
            applySyntaxHighlighting(in: range)
        }
    }
    #else
    // UITextView handles text insertion differently - use text did change notifications instead
    #endif
    
    // MARK: - Text Properties
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var text: String? {
        get {
            string
        }
        set {
            let textEditingService = BusinessLogic.textEditing
            // Use a large limit for text validation - maxSyntaxHighlightingLength is for highlighting only
            let validationResult = textEditingService.validateTextChange(
                newText: newValue, 
                maxLength: 100_000_000 // 100MB limit for text
            )
            
            switch validationResult {
            case .valid(let sanitizedText):
                string = sanitizedText

            case .invalid(let reason):
                Self.logger.warning("Text change rejected: \(String(describing: reason))")
                // Keep the original text if validation fails
                // This is safer than clearing the text
            }
        }
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var attributedText: NSAttributedString? {
        get {
            textStorage
        }
        set {
            if let newValue {
                textStorage?.setAttributedString(newValue)
            } else {
                string = ""
            }
        }
    }
    #endif
    
    public var textSelection: NSRange {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            selectedRange
            #else
            selectedRange
            #endif
        }
        set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            // Use the method that respects autoScrollToCursor configuration
            setSelectedRangeWithoutScrolling(newValue)
            #else
            Self.logger.debug("📍 selectedRange setter called with range: \(newValue), autoScrollToCursor: \(self.configuration.behavior.autoScrollToCursor)")
            // Use the method that respects autoScrollToCursor configuration
            setSelectedRangeWithoutScrolling(newValue)
            #endif
        }
    }
    
    // MARK: - TextKit Properties
    
    /// Get the text content storage for TextKit2 operations
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public var textContentStorage: NSTextContentStorage? {
        textLayoutManager?.textContentManager as? NSTextContentStorage
    }
    #else
    public var textContentStorage: NSTextContentStorage? {
        textLayoutManager?.textContentManager as? NSTextContentStorage
    }
    #endif
    
    public var widthTracksTextView: Bool {
        get {
            let textKitBridge = TextKitBridge(textView: self)
            return textKitBridge.widthTracksTextView
        }
        set {
            let textKitBridge = TextKitBridge(textView: self)
            textKitBridge.widthTracksTextView = newValue
        }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public var isHorizontallyResizable: Bool {
        get {
            super.isHorizontallyResizable
        }
        set {
            super.isHorizontallyResizable = newValue
        }
    }
    #endif

    public var heightTracksTextView: Bool {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let textContainer = super.textContainer {
                return textContainer.heightTracksTextView
            } else {
                return true
            }
            #elseif targetEnvironment(macCatalyst)
            let textContainer = super.textContainer
            return textContainer.heightTracksTextView
            #else
            return true // UITextView doesn't have this property
            #endif
        }
        set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let textContainer = super.textContainer {
                textContainer.heightTracksTextView = newValue
            }
            #elseif targetEnvironment(macCatalyst)
            let textContainer = super.textContainer
            textContainer.heightTracksTextView = newValue
            #endif
        }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public var isVerticallyResizable: Bool {
        get {
            super.isVerticallyResizable
        }
        set {
            super.isVerticallyResizable = newValue
        }
    }
    #endif
    
    // MARK: - Text Range Operations
    
    public func shouldChangeText(in textRange: NSTextRange, replacementString: String?) -> Bool {
        // Check if editing is allowed
        guard configuration.behavior.isEditable else { return false }
        
        // Convert NSTextRange to NSRange for compatibility
        let textKitBridge = TextKitBridge(textView: self)
        if textKitBridge.version == .textKit2 {
            // Use TextKit2 conversion
            if let nsRange = textKitBridge.nsRangeFromTextRange(textRange) {
                // Call delegate method with proper range
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                return delegate?.textView?(self, shouldChangeTextIn: nsRange, replacementString: replacementString) ?? true
                #else
                return delegate?.textView?(self, shouldChangeTextIn: nsRange, replacementText: replacementString ?? "") ?? true
                #endif
            }
        } else {
            // Use fallback conversion for TextKit1
            if let textContentManager = textLayoutManager?.textContentManager {
                let nsRange = NSRange(textRange, in: textContentManager)
                // Delegate is called with NSRange
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                return delegate?.textView?(self, shouldChangeTextIn: nsRange, replacementString: replacementString) ?? true
                #else
                return delegate?.textView?(self, shouldChangeTextIn: nsRange, replacementText: replacementString ?? "") ?? true
                #endif
            }
        }
        
        return true
    }

    public func replaceCharacters(in textRange: NSTextRange, with string: String) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage else { return }
        #else
        let textStorage = self.textStorage
        #endif
        
        // Convert NSTextRange to NSRange
        let textKitBridge = TextKitBridge(textView: self)
        let nsRange: NSRange
        
        if textKitBridge.version == .textKit2 {
            // Use TextKit2 conversion
            if let convertedRange = textKitBridge.nsRangeFromTextRange(textRange) {
                nsRange = convertedRange
            } else {
                // Fallback to current selection if conversion fails
                nsRange = selectedRange
            }
        } else {
            // Use fallback conversion for TextKit1
            if let textContentManager = textLayoutManager?.textContentManager {
                nsRange = NSRange(textRange, in: textContentManager)
            } else {
                // Last resort: try direct conversion with UTF16TextLocation
                nsRange = NSRange(textRange) ?? selectedRange
            }
        }
        
        // Perform the replacement
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: nsRange, with: string)
        textStorage.endEditing()
        
        // Update syntax highlighting for the affected area if enabled
        if isSyntaxHighlightingEnabled {
            let affectedRange = NSRange(location: nsRange.location, length: string.count)
            applySyntaxHighlighting(in: affectedRange)
        }
        
        // Notify delegate
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
        #else
        // UITextView will send its own notification
        #endif
    }
    
    // MARK: - TextKit Helper Methods
    
    /// Calculate line rect using TextKit2-compatible approach that doesn't force TextKit1
    internal func calculateLineRect(for range: NSRange) -> CGRect? {
        let textKitBridge = TextKitBridge(textView: self)
        return textKitBridge.boundingRect(for: range)
    }

    // MARK: - TextKit Version Detection
    
    /// Detects which TextKit version is currently being used and logs warnings for compatibility mode
    public func detectTextKitVersion() -> String {
        let textKitBridge = TextKitBridge(textView: self)
        let version = textKitBridge.version
        
        #if canImport(UIKit)
        if version == .textKit2 {
            Self.logger.info("✅ Using TextKit 2 with textLayoutManager")
            return "TextKit 2"
        } else {
            Self.logger.warning("⚠️ TextKit 2 not available - using TextKit 1 fallback")
            return "TextKit 1 (fallback)"
        }
        #else
        if version == .textKit2 {
            Self.logger.info("✅ Using TextKit 2 with textLayoutManager")
            return "TextKit 2"
        } else if responds(to: #selector(getter: NSTextView.layoutManager)) {
            Self.logger.warning("❌ TextKit 1 compatibility mode active - this may cause performance issues")
            return "TextKit 1 (compatibility mode)"
        } else {
            Self.logger.warning("⚠️ TextKit 2 not available - using TextKit 1 fallback")
            return "TextKit 1 (fallback)"
        }
        #endif
    }
    
    /// Validates that TextKit 2 is being used properly
    public func validateTextKit2Usage() -> Bool {
        let textKitBridge = TextKitBridge(textView: self)
        let isUsingTextKit2 = textKitBridge.version == .textKit2
        
        if !isUsingTextKit2 {
            Self.logger.warning("TextKit 2 validation failed: \(textKitBridge.version.description)")
        }
        
        return isUsingTextKit2
    }

    // MARK: - NSTextLayoutOrientationProvider

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public nonisolated var layoutOrientation: NSLayoutManager.TextLayoutOrientation {
        // For NSTextView, we'll default to horizontal layout
        .horizontal
    }
    #endif

    // MARK: - NSTextLayoutManagerDelegate

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public nonisolated func textLayoutManager(
        _: NSTextLayoutManager,
        textLayoutFragmentFor _: NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        // Create the fragment with default paragraph style
        // The style will be updated later if needed
        TextLayoutFragment(
            textElement: textElement,
            range: textElement.elementRange,
            paragraphStyle: NSParagraphStyle.default
        )
    }
    #endif
}
