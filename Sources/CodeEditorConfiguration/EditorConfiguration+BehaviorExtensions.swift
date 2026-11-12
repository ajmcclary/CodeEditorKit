import CodeEditorPlatform
import Foundation

extension EditorConfiguration {
    /// Behavior configuration options for editing features.
    ///
    /// Controls editing behaviors including auto-indentation, completion,
    /// and text processing features.
    public struct Behavior: Equatable, Sendable {
        // MARK: - Properties

        /// Whether the editor is editable
        public var isEditable: Bool = true

        /// Whether the editor is selectable
        public var isSelectable: Bool = true

        /// Whether Return keeps the current line's indentation, one level
        /// deeper after an opening bracket or a trailing colon.
        public var isAutoIndentEnabled: Bool = true

        /// Whether code completion is enabled.
        public var isCodeCompletionEnabled: Bool = true

        /// Whether URLs in the text are detected and drawn as links.
        public var isAutomaticLinkDetectionEnabled: Bool = false

        /// Whether to enable automatic quote substitution
        public var isAutomaticQuoteSubstitutionEnabled: Bool = false

        /// Whether to enable automatic dash substitution
        public var isAutomaticDashSubstitutionEnabled: Bool = false

        /// Whether typing `(`, `[` or `{` also inserts its closer, and typing
        /// a closer that is already there steps over it.
        public var autoCloseBrackets: Bool = true

        /// Whether typing `"`, `'` or a backtick also inserts its pair.
        public var autoCloseQuotes: Bool = true

        /// Whether to enable continuous spell checking
        public var isContinuousSpellCheckingEnabled: Bool = false

        /// Whether to enable grammar checking
        public var isGrammarCheckingEnabled: Bool = false

        /// Whether to enable automatic text replacement
        public var isAutomaticTextReplacementEnabled: Bool = false

        /// Whether to enable automatic spelling correction
        public var isAutomaticSpellingCorrectionEnabled: Bool = false

        /// Whether to enable automatic text completion
        public var isAutomaticTextCompletionEnabled: Bool = false

        /// Whether the system's inline predictions may appear in the editor.
        ///
        /// `true` follows the user's system-wide setting; `false` never shows
        /// them here.
        public var showInlineCompletionSuggestions: Bool = true

        /// The characters that open the completion list when typed.
        ///
        /// While this holds `defaultCompletionTriggerCharacters` the editor
        /// uses the current language's own trigger characters instead; any
        /// other value is used as given, for every language.
        public var completionTriggerCharacters: Set<Character> = Self.defaultCompletionTriggerCharacters

        /// The initial `completionTriggerCharacters`, which stands for "use
        /// the language's own".
        public static let defaultCompletionTriggerCharacters: Set<Character> = [".", ":", "\"", "'", "/", "<", " "]

        /// Whether to automatically scroll to cursor position.
        ///
        /// When enabled, the editor automatically scrolls to make the cursor
        /// visible when navigating to a specific line or position (e.g., via
        /// minimap clicks, symbol navigation, or search results).
        ///
        /// When disabled, navigation actions will move the cursor but won't
        /// automatically scroll the view.
        ///
        /// - Note: This does not affect manual scrolling or cursor movement.
        public var autoScrollToCursor: Bool = false

        // MARK: - Initialization

        public init() {}
    }
}

// MARK: - Codable Implementation

extension EditorConfiguration.Behavior: Codable {
    private enum CodingKeys: String, CodingKey {
        case isEditable
        case isSelectable
        case isAutoIndentEnabled
        case isCodeCompletionEnabled
        case isAutomaticLinkDetectionEnabled
        case isAutomaticQuoteSubstitutionEnabled
        case isAutomaticDashSubstitutionEnabled
        case autoCloseBrackets
        case autoCloseQuotes
        case isContinuousSpellCheckingEnabled
        case isGrammarCheckingEnabled
        case isAutomaticTextReplacementEnabled
        case isAutomaticSpellingCorrectionEnabled
        case isAutomaticTextCompletionEnabled
        case showInlineCompletionSuggestions
        case completionTriggerCharacters
        case autoScrollToCursor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEditable = try container.decodeIfPresent(Bool.self, forKey: .isEditable) ?? true
        isSelectable = try container.decodeIfPresent(Bool.self, forKey: .isSelectable) ?? true
        isAutoIndentEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutoIndentEnabled) ?? true
        isCodeCompletionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isCodeCompletionEnabled) ?? true
        isAutomaticLinkDetectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticLinkDetectionEnabled) ?? false
        isAutomaticQuoteSubstitutionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticQuoteSubstitutionEnabled) ?? false
        isAutomaticDashSubstitutionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticDashSubstitutionEnabled) ?? false
        showInlineCompletionSuggestions = try container.decodeIfPresent(Bool.self, forKey: .showInlineCompletionSuggestions) ?? true

        if let characters = try container.decodeIfPresent(String.self, forKey: .completionTriggerCharacters) {
            completionTriggerCharacters = Set(characters)
        } else {
            completionTriggerCharacters = Self.defaultCompletionTriggerCharacters
        }

        // Additional properties with defaults
        autoCloseBrackets = try container.decodeIfPresent(Bool.self, forKey: .autoCloseBrackets) ?? true
        autoCloseQuotes = try container.decodeIfPresent(Bool.self, forKey: .autoCloseQuotes) ?? true
        isContinuousSpellCheckingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isContinuousSpellCheckingEnabled) ?? false
        isGrammarCheckingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGrammarCheckingEnabled) ?? false
        isAutomaticTextReplacementEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticTextReplacementEnabled) ?? false
        isAutomaticSpellingCorrectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticSpellingCorrectionEnabled) ?? false
        isAutomaticTextCompletionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticTextCompletionEnabled) ?? false
        autoScrollToCursor = try container.decodeIfPresent(Bool.self, forKey: .autoScrollToCursor) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEditable, forKey: .isEditable)
        try container.encode(isSelectable, forKey: .isSelectable)
        try container.encode(isAutoIndentEnabled, forKey: .isAutoIndentEnabled)
        try container.encode(isCodeCompletionEnabled, forKey: .isCodeCompletionEnabled)
        try container.encode(isAutomaticLinkDetectionEnabled, forKey: .isAutomaticLinkDetectionEnabled)
        try container.encode(isAutomaticQuoteSubstitutionEnabled, forKey: .isAutomaticQuoteSubstitutionEnabled)
        try container.encode(isAutomaticDashSubstitutionEnabled, forKey: .isAutomaticDashSubstitutionEnabled)
        try container.encode(showInlineCompletionSuggestions, forKey: .showInlineCompletionSuggestions)
        // Encode as a sorted string so equivalent configurations
        // produce identical JSON. `Set<Character>` iteration order is
        // unstable across runs, which would otherwise cause noisy
        // snapshot diffs and break content-hash-based caching of
        // encoded configurations.
        try container.encode(String(completionTriggerCharacters.sorted()), forKey: .completionTriggerCharacters)
        try container.encode(autoCloseBrackets, forKey: .autoCloseBrackets)
        try container.encode(autoCloseQuotes, forKey: .autoCloseQuotes)
        try container.encode(isContinuousSpellCheckingEnabled, forKey: .isContinuousSpellCheckingEnabled)
        try container.encode(isGrammarCheckingEnabled, forKey: .isGrammarCheckingEnabled)
        try container.encode(isAutomaticTextReplacementEnabled, forKey: .isAutomaticTextReplacementEnabled)
        try container.encode(isAutomaticSpellingCorrectionEnabled, forKey: .isAutomaticSpellingCorrectionEnabled)
        try container.encode(isAutomaticTextCompletionEnabled, forKey: .isAutomaticTextCompletionEnabled)
        try container.encode(autoScrollToCursor, forKey: .autoScrollToCursor)
    }
}
