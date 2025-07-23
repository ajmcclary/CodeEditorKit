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
    /// The plain text content of the editor.
    ///
    /// This property provides access to the text content as a plain string, without any formatting
    /// or attributes. Setting this property will replace all text in the editor while preserving
    /// the current configuration and syntax highlighting settings.
    ///
    /// ## Text Validation
    ///
    /// Text changes are validated through the `TextEditingService` with a 100MB size limit.
    /// Invalid text changes are rejected and logged as warnings.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Set text content
    /// editor.text = "func hello() { NSLog(\"Hello, World!\") }"
    ///
    /// // Get current text
    /// let currentText = editor.text ?? ""
    /// ```
    ///
    /// - Note: This property is only available on macOS. On iOS, use the inherited `text` property.
    public var text: String? {
        get {
            string
        }
        set {
            let textEditingService = businessLogicServices.textEditingService
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
    /// The attributed text content of the editor.
    ///
    /// This property provides access to the text content with all formatting attributes,
    /// including syntax highlighting, font styles, and colors. Setting this property
    /// will replace all content while preserving text attributes.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Get attributed text with formatting
    /// let styledText = editor.attributedText
    ///
    /// // Set pre-formatted text
    /// let attributed = NSAttributedString(string: "code", attributes: [.foregroundColor: NSColor.blue])
    /// editor.attributedText = attributed
    /// ```
    ///
    /// - Note: This property is only available on macOS. On iOS, use the inherited `attributedText` property.
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

    /// The current text selection range.
    ///
    /// This property provides cross-platform access to the selected text range in the editor.
    /// Setting this property will move the cursor or selection to the specified range,
    /// respecting the `autoScrollToCursor` configuration setting.
    ///
    /// ## Behavior
    ///
    /// - **Get**: Returns the current selection range as an `NSRange`
    /// - **Set**: Updates the selection and optionally scrolls to make it visible
    /// - Respects the `configuration.behavior.autoScrollToCursor` setting
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Select characters 10-20
    /// editor.textSelection = NSRange(location: 10, length: 10)
    ///
    /// // Move cursor to position 50
    /// editor.textSelection = NSRange(location: 50, length: 0)
    ///
    /// // Get current selection
    /// let selection = editor.textSelection
    /// ```
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
    /// Access to the TextKit2 text content storage.
    ///
    /// This property provides access to the underlying `NSTextContentStorage` used by TextKit2
    /// for text storage and management. This is primarily used for advanced text manipulation
    /// and TextKit2-specific operations.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// if let storage = editor.textContentStorage {
    ///     // Perform TextKit2 operations
    ///     let textElements = storage.textElements(for: range)
    /// }
    /// ```
    ///
    /// - Returns: The text content storage if TextKit2 is available, `nil` otherwise
    /// - Note: This property is available on iOS and Mac Catalyst
    public var textContentStorage: NSTextContentStorage? {
        textLayoutManager?.textContentManager as? NSTextContentStorage
    }
    #endif

    /// Controls whether the text container width tracks the text view width.
    ///
    /// When enabled, the text container automatically adjusts its width to match
    /// the text view's width. This affects text wrapping behavior and layout.
    ///
    /// ## Behavior
    ///
    /// - **`true`**: Text container width follows text view width (enables wrapping)
    /// - **`false`**: Text container maintains independent width (may cause horizontal scrolling)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Enable text wrapping
    /// editor.widthTracksTextView = true
    ///
    /// // Allow horizontal scrolling
    /// editor.widthTracksTextView = false
    /// ```
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

    /// Controls whether the text container height tracks the text view height.
    ///
    /// When enabled, the text container automatically adjusts its height to match
    /// the text view's height. This affects vertical layout and scrolling behavior.
    ///
    /// ## Platform Differences
    ///
    /// - **macOS**: Uses `NSTextContainer.heightTracksTextView`
    /// - **Mac Catalyst**: Uses `UITextView.textContainer.heightTracksTextView`
    /// - **iOS**: Always returns `true` (property not available)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Enable height tracking
    /// editor.heightTracksTextView = true
    ///
    /// // Disable height tracking for custom sizing
    /// editor.heightTracksTextView = false
    /// ```
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

    /// Determines whether text should be changed in the specified range.
    ///
    /// This method is called before text changes are applied to determine if the change
    /// should be allowed. It checks editor configuration and delegates to the text view's
    /// delegate for validation.
    ///
    /// ## Validation Process
    ///
    /// 1. Checks if editing is enabled in configuration
    /// 2. Converts TextKit2 `NSTextRange` to `NSRange` for compatibility
    /// 3. Calls the delegate's `shouldChangeText` method
    ///
    /// ## Parameters
    ///
    /// - Parameter textRange: The range of text to be changed (TextKit2 format)
    /// - Parameter replacementString: The replacement text, or `nil` for deletions
    ///
    /// ## Returns
    ///
    /// `true` if the text change should be allowed, `false` otherwise
    ///
    /// ## Example
    ///
    /// ```swift
    /// // This method is typically called internally by the text system
    /// let shouldChange = editor.shouldChangeText(in: textRange, replacementString: "new text")
    /// ```
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

    /// Replaces characters in the specified TextKit2 range with new text.
    ///
    /// This method provides a TextKit2-compatible interface for text replacement,
    /// handling the conversion between `NSTextRange` and `NSRange` formats and
    /// updating syntax highlighting for the affected area.
    ///
    /// ## Features
    ///
    /// - Automatic TextKit2 to TextKit1 range conversion
    /// - Syntax highlighting updates for changed text
    /// - Delegate notifications for text changes
    /// - Fallback handling for range conversion failures
    ///
    /// ## Parameters
    ///
    /// - Parameter textRange: The range of text to replace (TextKit2 format) 
    /// - Parameter string: The replacement text
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Replace text in a specific range
    /// if let textRange = editor.textRange(for: nsRange) {
    ///     editor.replaceCharacters(in: textRange, with: "replacement text")
    /// }
    /// ```
    ///
    /// - Note: This method automatically triggers syntax highlighting updates if enabled
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
    /// Creates a text layout fragment for the specified text element.
    ///
    /// This method is part of the `NSTextLayoutManagerDelegate` protocol and is called
    /// by TextKit2 to create layout fragments for text elements. It provides custom
    /// layout fragment creation with default paragraph styling.
    ///
    /// ## Implementation Details
    ///
    /// - Creates `TextLayoutFragment` instances with default paragraph style
    /// - Styles are applied later in the layout process as needed
    /// - Supports TextKit2's advanced layout capabilities
    ///
    /// ## Parameters
    ///
    /// - Parameter textLayoutManager: The layout manager requesting the fragment
    /// - Parameter location: The text location for the fragment
    /// - Parameter textElement: The text element to create a fragment for
    ///
    /// ## Returns
    ///
    /// A configured `NSTextLayoutFragment` for the specified text element
    ///
    /// - Note: This method is marked `nonisolated` for TextKit2 compatibility
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
