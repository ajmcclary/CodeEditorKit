import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Smart editing engine for auto-brackets, multi-cursor, and other intelligent features
///
/// This class coordinates smart editing functionality by delegating to focused components:
/// - `AutoBracketingEngine`: Handles automatic bracket and quote pair insertion
/// - `MultiCursorEditor`: Manages multi-cursor editing
/// - `SmartIndentationEngine`: Calculates automatic indentation
/// - `SmartSelectionExpander`: Expands selections to logical boundaries
@MainActor
public final class SmartEditingEngine: NSObject, ObservableObject {
    #if canImport(AppKit)
    public typealias PlatformTextViewDelegate = NSTextViewDelegate
    #else
    public typealias PlatformTextViewDelegate = UITextViewDelegate
    #endif

    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "SmartEditingEngine")

    // MARK: - Published Properties

    @Published public var configuration = SmartEditingConfiguration()
    @Published public private(set) var isMultiCursorMode = false

    /// All active cursors (read from multi-cursor editor)
    public var cursors: [TextCursor] {
        multiCursorEditor.cursors
    }

    // MARK: - Components

    private let multiCursorEditor = MultiCursorEditor()

    // MARK: - Properties

    private weak var textView: CodeEditorView?
    private var bracketPairs: [SmartEditingBracketPair] = []
    private var autoIndentRules: [AutoIndentRule] = []

    // MARK: - Initialization

    override public init() {
        super.init()
        setupDefaultRules()
    }

    /// Attach to a text view by registering as a behavior-phase
    /// delegate participant.
    ///
    /// The framework's `TextViewDelegateMultiplexer` is the sole owner
    /// of `textView.delegate`; registering at `.behavior` means smart-
    /// editing interception (auto-bracket, auto-indent, multi-cursor)
    /// runs *after* host gating. A host's `CodeEditorViewDelegate`
    /// returning `false` from `shouldChangeTextIn` short-circuits
    /// before this engine's intercept fires.
    public func attach(to textView: CodeEditorView) {
        self.textView = textView
        textView.addDelegateParticipant(self, phase: .behavior)
    }

    /// Detach from the previously-attached text view, removing the
    /// engine from the delegate multiplexer. Idempotent — calling
    /// `detach()` without a prior `attach(to:)` is a no-op.
    public func detach() {
        textView?.removeDelegateParticipant(self)
        textView = nil
    }

    private func setupDefaultRules() {
        // Setup default bracket pairs
        bracketPairs = [
            SmartEditingBracketPair(open: "(", close: ")"),
            SmartEditingBracketPair(open: "[", close: "]"),
            SmartEditingBracketPair(open: "{", close: "}"),
            SmartEditingBracketPair(open: "\"", close: "\"", isQuote: true),
            SmartEditingBracketPair(open: "'", close: "'", isQuote: true),
            SmartEditingBracketPair(open: "`", close: "`", isQuote: true)
        ]

        // Setup auto-indent rules
        autoIndentRules = SmartIndentationEngine.defaultRules()
    }

    // MARK: - Multi-Cursor Support

    /// Add a cursor at the specified location
    public func addCursor(at location: Int) {
        multiCursorEditor.addCursor(at: location)
        isMultiCursorMode = multiCursorEditor.isMultiCursorMode
        multiCursorEditor.updateVisuals()
    }

    /// Add cursors at all occurrences of selected text
    public func addCursorsAtOccurrences() {
        guard let textView else { return }
        multiCursorEditor.addCursorsAtOccurrences(in: textView)
        isMultiCursorMode = multiCursorEditor.isMultiCursorMode
    }

    /// Clear all extra cursors
    public func clearMultiCursors() {
        multiCursorEditor.clearAllCursors()
        isMultiCursorMode = false
        multiCursorEditor.updateVisuals()
    }

    // MARK: - Smart Selection

    /// Expand selection to logical boundaries
    public func expandSelection() {
        guard let textView else { return }
        SmartSelectionExpander.expandSelection(in: textView)
    }

    // MARK: - Internal Handlers

    /// Handle character insertion for auto-bracket functionality
    private func handleCharacterInsertion(_ text: String, at range: NSRange) -> Bool {
        guard let textView else { return false }
        return AutoBracketingEngine.handleCharacterInsertion(
            text,
            at: range,
            in: textView,
            bracketPairs: bracketPairs,
            configuration: configuration
        )
    }

    /// Handle text input with multiple cursors
    private func handleMultiCursorInput(_ text: String) -> Bool {
        guard let textView else { return false }
        let result = multiCursorEditor.handleInput(text, in: textView)
        multiCursorEditor.updateVisuals()
        return result
    }

    /// Calculate indentation for a new line
    private func calculateIndentation(at location: Int) -> String {
        guard let textView else { return "" }
        return SmartIndentationEngine.calculateIndentation(
            at: location,
            in: textView,
            rules: autoIndentRules,
            configuration: configuration
        )
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - TextViewDelegateParticipant

extension SmartEditingEngine: TextViewDelegateParticipant {
    public func textView(
        _ textView: CodeEditorView,
        shouldChangeTextIn range: NSRange,
        replacementString: String?
    ) -> Bool {
        guard let text = replacementString else { return true }

        // Handle multi-cursor input.
        if isMultiCursorMode && !text.isEmpty {
            return !handleMultiCursorInput(text)
        }

        // Handle auto-bracket insertion.
        if text.count == 1 {
            if handleCharacterInsertion(text, at: range) {
                return false
            }
        }

        // Handle enter key for auto-indentation.
        if text == "\n" && configuration.isAutoIndentEnabled {
            let indentation = calculateIndentation(at: range.location)
            if !indentation.isEmpty {
                textView.textKitBridge.replaceCharacters(
                    in: range,
                    with: "\n" + indentation
                )
                return false
            }
        }

        return true
    }

    public func textViewDidChangeSelection(_ codeEditorView: CodeEditorView) {
        // Update multi-cursor mode if needed.
        if isMultiCursorMode && codeEditorView.selectedRange.length > 0 {
            // Selection made, might want to exit multi-cursor mode
            // or update cursor positions.
        }
    }
}

// MARK: - Supporting Types

/// Text cursor for multi-cursor editing
public struct TextCursor: Identifiable {
    public let id = UUID()
    public var location: Int
    public var selection: Int = 0

    public var range: NSRange {
        NSRange(location: location, length: selection)
    }
}

/// Bracket pair definition for smart editing
public struct SmartEditingBracketPair {
    /// The opening bracket or quote character
    public let open: String
    /// The closing bracket or quote character
    public let close: String
    /// Whether this pair represents quote characters
    public let isQuote: Bool

    /// Creates a new bracket pair definition
    /// - Parameters:
    ///   - open: The opening bracket or quote character
    ///   - close: The closing bracket or quote character
    ///   - isQuote: Whether this pair represents quote characters
    public init(open: String, close: String, isQuote: Bool = false) {
        self.open = open
        self.close = close
        self.isQuote = isQuote
    }
}

/// Auto-indent rule
public struct AutoIndentRule {
    /// The trigger character or pattern that activates this rule
    public let trigger: String
    /// The indentation action to perform when triggered
    public let action: IndentAction

    /// Actions that can be performed for auto-indentation
    public enum IndentAction {
        /// Increase the indentation level for the current line
        case increaseIndent
        /// Decrease the indentation level for the current line
        case decreaseIndent
        /// Increase the indentation level for the next line
        case increaseIndentNext
        /// Maintain the current indentation level
        case maintainIndent
    }
}

/// Smart editing configuration
public struct SmartEditingConfiguration {
    // Auto-bracket insertion
    /// Whether to automatically insert closing brackets
    public var autoInsertBrackets = true
    /// Whether to automatically insert closing quotes
    public var autoInsertQuotes = true
    /// Whether to wrap selected text with brackets or quotes
    public var wrapSelection = true

    // Multi-cursor
    /// Whether multi-cursor editing is enabled
    public var enableMultiCursor = true

    #if canImport(AppKit)
    /// The modifier key used for multi-cursor operations on macOS
    public var multiCursorModifierKey: NSEvent.ModifierFlags = .option
    #else
    /// The modifier key used for multi-cursor operations on iOS
    public var multiCursorModifierKey: UIKeyModifierFlags = .alternate
    #endif

    // Auto-indentation
    /// Whether automatic indentation is enabled
    public var isAutoIndentEnabled = true
    /// Whether to insert spaces instead of tab characters
    public var insertSpacesForTabs = true
    /// The number of spaces per tab level
    public var tabWidth = 4
    /// Whether to automatically detect indentation style from existing content
    public var detectIndentation = true

    // Smart selection
    /// Whether smart selection expansion is enabled
    public var enableSmartSelection = true
    /// The sequence of selection expansion stops
    public var expandSelectionStops: [SelectionStop] = [.word, .line, .scope, .all]

    /// Selection expansion stops for smart selection
    public enum SelectionStop {
        /// Expand to the current word
        case word
        /// Expand to the current line
        case line
        /// Expand to the current scope (brackets, braces, etc.)
        case scope
        /// Expand to select all content
        case all
    }
}
