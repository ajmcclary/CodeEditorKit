import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - TextKit & Text Management

extension CodeEditorView {
    // MARK: - Text Changes

    #if canImport(AppKit)
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

    #if canImport(AppKit)
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
            let textEditingService = featureDependencies.textEditingService
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

    #if canImport(AppKit)
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
                rebuildLineGeometryStoreFromCurrentTextStorage()
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
            #if canImport(AppKit)
            selectedRange
            #else
            selectedRange
            #endif
        }
        set {
            #if canImport(AppKit)
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
    #if canImport(AppKit)
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
    /// - Note: This property is available on iOS
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

    #if canImport(AppKit)
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
    /// - **iOS**: Uses `UITextView.textContainer.heightTracksTextView`
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
            #if canImport(AppKit)
            if let textContainer = super.textContainer {
                return textContainer.heightTracksTextView
            } else {
                return true
            }
            #else
            return true // UITextView doesn't have this property
            #endif
        }
        set {
            #if canImport(AppKit)
            if let textContainer = super.textContainer {
                textContainer.heightTracksTextView = newValue
            }
            #endif
        }
    }

    #if canImport(AppKit)
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
    /// This method is the pre-mutation hook for TextKit2 edits. It publishes a
    /// `WillEditEvent` so downstream consumers can capture state before
    /// `NSTextStorage` mutates.
    ///
    /// ## Validation Process
    ///
    /// 1. Checks if editing is enabled in configuration
    /// 2. Converts TextKit2 `NSTextRange` to `NSRange` for compatibility
    /// 3. Calls the delegate's `shouldChangeText` method
    /// 4. Publishes `WillEditEvent` to will-edit observers after validation
    ///    succeeds
    ///
    /// ## Parameters
    ///
    /// - Parameter textRange: The range of text to be changed (TextKit2 format)
    /// - Parameter replacementString: The replacement text, or `nil` for deletions
    ///
    /// ## Returns
    ///
    /// `true` if the text change should be allowed, `false` otherwise
    public func shouldChangeText(in textRange: NSTextRange, replacementString: String?) -> Bool {
        // Check if editing is allowed
        guard configuration.behavior.isEditable else { return false }

        let textKitBridge = TextKitBridge(textView: self)
        if let nsRange = textKitBridge.nsRangeFromTextRange(textRange) {
            let allowed: Bool
            #if canImport(AppKit)
            if let proxy = delegate as? CodeEditorViewDelegateProxy,
               proxy === delegateProxy {
                allowed = proxy.source?.textView(
                    self,
                    shouldChangeTextIn: textRange,
                    replacementString: replacementString
                ) ?? true
            } else {
                allowed = delegate?.textView?(self, shouldChangeTextIn: nsRange, replacementString: replacementString) ?? true
            }
            #else
            allowed = delegateProxy.source?.textView(
                self,
                shouldChangeTextIn: textRange,
                replacementString: replacementString
            ) ?? true
            #endif

            guard allowed else { return false }

            // Publish pre-edit event only after validation succeeds.
            publishWillEditEvent(range: nsRange, replacementText: replacementString ?? "")
            return true
        }
        return true
    }

    /// Constructs and publishes a `WillEditEvent` to the event hub's
    /// will-edit observer set.
    internal func publishWillEditEvent(range: NSRange, replacementText: String) {
        #if canImport(AppKit)
        let source = textStorage?.string ?? ""
        #else
        let source = textStorage.string
        #endif

        // Compute the affected line range before the edit.
        // Counts newlines up to the edit boundaries. O(offset) — acceptable
        // because the edit point is where the user is typing (near-constant
        // cost in practice for interactive edits).
        let preEditLineRange = computePreEditLineRange(
            in: source,
            location: range.location,
            length: range.length
        )

        // Capture the old source text in the affected region using
        // native Swift indexing (avoids NSString bridging lint).
        let preEditSource: String?
        let safeLower = max(0, range.location)
        let safeUpper = min(range.location + range.length, source.utf16.count)
        if safeLower < safeUpper {
            let startIdx = source.utf16.index(source.utf16.startIndex, offsetBy: safeLower)
            let endIdx = source.utf16.index(source.utf16.startIndex, offsetBy: safeUpper)
            preEditSource = String(source.utf16[startIdx..<endIdx])
        } else {
            preEditSource = nil
        }

        let event = WillEditEvent(
            preEditRange: range,
            replacementText: replacementText,
            preEditLineRange: preEditLineRange,
            preEditSource: preEditSource
        )
        textEditEventHub.willPublish(event)
    }

    /// Returns the 1-based line range affected by an edit at `location`
    /// spanning `length` UTF-16 code units.
    private func computePreEditLineRange(
        in source: String,
        location: Int,
        length: Int
    ) -> ClosedRange<Int> {
        let utf16 = source.utf16
        var lineNumber = 1
        var cursor = utf16.startIndex
        var pos = 0

        // Advance to the start position.
        while pos < location, cursor < utf16.endIndex {
            if utf16[cursor] == 0x0A { lineNumber &+= 1 } // U+000A LINE FEED
            utf16.formIndex(after: &cursor)
            pos &+= 1
        }
        let startLine = lineNumber

        // Advance through the affected length.
        let endPos = min(location + length, source.utf16.count)
        while pos < endPos, cursor < utf16.endIndex {
            if utf16[cursor] == 0x0A { lineNumber &+= 1 }
            utf16.formIndex(after: &cursor)
            pos &+= 1
        }
        let endLine = endPos > location ? lineNumber : startLine

        return startLine...endLine
    }

    /// Replaces characters in the specified TextKit2 range with new text.
    ///
    /// Converts the supplied `NSTextRange` to an `NSRange` via `TextKitBridge`
    /// and applies the replacement to the text storage, then triggers
    /// syntax-highlighting + delegate notifications for the affected area.
    ///
    /// - Parameter textRange: The range of text to replace.
    /// - Parameter string: The replacement text.
    public func replaceCharacters(in textRange: NSTextRange, with string: String) {
        #if canImport(AppKit)
        guard let textStorage else { return }
        #else
        let textStorage = self.textStorage
        #endif

        let textKitBridge = TextKitBridge(textView: self)
        let nsRange = textKitBridge.nsRangeFromTextRange(textRange) ?? selectedRange

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
        #if canImport(AppKit)
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
        #else
        // UITextView will send its own notification
        #endif
    }

    // MARK: - TextKit Helper Methods

    /// Calculate line rect using TextKit2.
    internal func calculateLineRect(for range: NSRange) -> CGRect? {
        let textKitBridge = TextKitBridge(textView: self)
        return textKitBridge.boundingRect(for: range)
    }

    // MARK: - TextKit Version Detection (compat shims)

    /// Always returns `"TextKit 2"`. Retained for API compatibility — consumers
    /// previously called this to log/inspect the TextKit version. As of 0.2.0
    /// the framework is TextKit2-only on every supported platform.
    public func detectTextKitVersion() -> String {
        "TextKit 2"
    }

    /// Always returns `true`. Retained for API compatibility.
    public func validateTextKit2Usage() -> Bool {
        true
    }

    // MARK: - NSTextLayoutOrientationProvider

    #if canImport(AppKit)
    override nonisolated public var layoutOrientation: NSLayoutManager.TextLayoutOrientation {
        // For NSTextView, we'll default to horizontal layout
        .horizontal
    }
    #endif

    // MARK: - NSTextLayoutManagerDelegate

    #if canImport(AppKit)
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
    nonisolated public func textLayoutManager(
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
