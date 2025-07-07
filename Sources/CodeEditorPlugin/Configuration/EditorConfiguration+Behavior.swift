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
        
        /// Whether to enable auto indentation
        public var autoIndent: Bool = true
        
        /// Whether to enable code completion
        public var enableCodeCompletion: Bool = true
        
        /// Alias for enableCodeCompletion for backward compatibility
        @available(*, deprecated, renamed: "enableCodeCompletion")
        public var codeCompletion: Bool {
            get { enableCodeCompletion }
            set { enableCodeCompletion = newValue }
        }
        
        /// Whether to detect links in text
        public var isAutomaticLinkDetectionEnabled: Bool = false
        
        /// Whether to enable automatic quote substitution
        public var isAutomaticQuoteSubstitutionEnabled: Bool = false
        
        /// Alias for isAutomaticQuoteSubstitutionEnabled for backward compatibility
        @available(*, deprecated, renamed: "isAutomaticQuoteSubstitutionEnabled")
        public var autoQuoteSubstitution: Bool {
            get { isAutomaticQuoteSubstitutionEnabled }
            set { isAutomaticQuoteSubstitutionEnabled = newValue }
        }
        
        /// Whether to enable automatic dash substitution
        public var isAutomaticDashSubstitutionEnabled: Bool = false
        
        /// Whether to automatically close brackets
        public var autoCloseBrackets: Bool = true
        
        /// Whether to automatically close quotes
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
        
        /// Whether to show completion suggestions inline
        public var showInlineCompletionSuggestions: Bool = true
        
        /// Completion trigger characters
        public var completionTriggerCharacters: Set<Character> = [".", ":", "\"", "'", "/", "<", " "]
        
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
        case autoIndent
        case enableCodeCompletion
        case isAutomaticLinkDetectionEnabled
        case isAutomaticQuoteSubstitutionEnabled
        case isAutomaticDashSubstitutionEnabled
        case showInlineCompletionSuggestions
        case completionTriggerCharacters
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEditable = try container.decodeIfPresent(Bool.self, forKey: .isEditable) ?? true
        isSelectable = try container.decodeIfPresent(Bool.self, forKey: .isSelectable) ?? true
        autoIndent = try container.decodeIfPresent(Bool.self, forKey: .autoIndent) ?? true
        enableCodeCompletion = try container.decodeIfPresent(Bool.self, forKey: .enableCodeCompletion) ?? true
        isAutomaticLinkDetectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticLinkDetectionEnabled) ?? false
        isAutomaticQuoteSubstitutionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticQuoteSubstitutionEnabled) ?? false
        isAutomaticDashSubstitutionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticDashSubstitutionEnabled) ?? false
        showInlineCompletionSuggestions = try container.decodeIfPresent(Bool.self, forKey: .showInlineCompletionSuggestions) ?? true
        
        if let characters = try container.decodeIfPresent(String.self, forKey: .completionTriggerCharacters) {
            completionTriggerCharacters = Set(characters)
        } else {
            completionTriggerCharacters = [".", ":", "\"", "'", "/", "<", " "]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEditable, forKey: .isEditable)
        try container.encode(isSelectable, forKey: .isSelectable)
        try container.encode(autoIndent, forKey: .autoIndent)
        try container.encode(enableCodeCompletion, forKey: .enableCodeCompletion)
        try container.encode(isAutomaticLinkDetectionEnabled, forKey: .isAutomaticLinkDetectionEnabled)
        try container.encode(isAutomaticQuoteSubstitutionEnabled, forKey: .isAutomaticQuoteSubstitutionEnabled)
        try container.encode(isAutomaticDashSubstitutionEnabled, forKey: .isAutomaticDashSubstitutionEnabled)
        try container.encode(showInlineCompletionSuggestions, forKey: .showInlineCompletionSuggestions)
        try container.encode(String(completionTriggerCharacters), forKey: .completionTriggerCharacters)
    }
}
