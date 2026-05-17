import CodeEditorLanguages
import CodeEditorTextModel
import Foundation

// MARK: - Text Parsing Utilities (Facade)

/// Unified text parsing and pattern matching utilities.
/// This facade re-exports functionality from focused modules in `Text/Parsing/`.
///
/// For new code, prefer importing the specific modules directly:
/// - `PatternExtractor` - notation pattern extraction
/// - `TokenExtractor` - token extraction and classification
/// - `IndentationAnalyzer` - indentation analysis
/// - `BracketMatcher` - brace/bracket matching
/// - `SyntaxTreeParser` - syntax tree parsing
/// - `LineEndingNormalizer` - line ending normalization
/// - `LanguagePatternDetector` - language detection
/// - `WordBoundaryFinder` - word boundary detection
public enum TextParsingUtilities {
    // MARK: - Re-exported Types

    /// Types of notation patterns for extracting programming language constructs.
    public typealias NotationType = PatternExtractor.NotationType

    /// Line ending type.
    public typealias LineEndingType = LineEndingNormalizer.LineEndingType

    /// Indentation information.
    public typealias IndentationInfo = IndentationAnalyzer.IndentationInfo

    /// A parsed token from text.
    public typealias TextToken = TokenExtractor.TextToken

    /// A hierarchical node in a parsed syntax tree.
    public typealias SyntaxNode = SyntaxTreeParser.SyntaxNode

    /// Word boundary detection mode.
    public typealias BoundaryMode = WordBoundaryFinder.BoundaryMode

    // MARK: - Pattern Extraction (delegates to PatternExtractor)

    /// Extracts target from various notation patterns.
    public static func extractTarget(from text: String, notation: NotationType) -> String? {
        PatternExtractor.extractTarget(from: text, notation: notation)
    }

    /// Extracts comment prefix for a given language.
    public static func extractCommentPrefix(for language: Language) -> String? {
        PatternExtractor.extractCommentPrefix(for: language)
    }

    /// Extracts tokens matching a specific pattern.
    public static func extractTokensMatching(
        pattern: String,
        in text: String,
        language: Language? = nil
    ) -> [TextToken] {
        TokenExtractor.extractTokensMatching(pattern: pattern, in: text, language: language)
    }

    // MARK: - Word Boundaries (delegates to WordBoundaryFinder)

    /// Finds word boundaries in text with enhanced accuracy.
    public static func findWordBoundaries(in text: String, mode: BoundaryMode = .standard) -> [Int] {
        WordBoundaryFinder.findWordBoundaries(in: text, mode: mode)
    }

    // MARK: - Indentation (delegates to IndentationAnalyzer)

    /// Extracts line indentation with detailed analysis.
    public static func extractLineIndentation(_ line: String, tabWidth: Int = 4) -> IndentationInfo {
        IndentationAnalyzer.extractLineIndentation(line, tabWidth: tabWidth)
    }

    // MARK: - Line Endings (delegates to LineEndingNormalizer)

    /// Normalizes line endings to specified format.
    public static func normalizeLineEndings(in text: String, to format: LineEndingType) -> String {
        LineEndingNormalizer.normalizeLineEndings(in: text, to: format)
    }

    // MARK: - Language Detection (delegates to LanguagePatternDetector)

    /// Detects programming language from content analysis.
    public static func detectLanguageFromContent(_ text: String) -> Language? {
        LanguagePatternDetector.detectLanguageFromContent(text)
    }

    /// Extracts string literals with proper escape handling.
    public static func extractStringLiterals(from text: String, language: Language) -> [NSRange] {
        LanguagePatternDetector.extractStringLiterals(from: text, language: language)
    }

    // MARK: - Bracket Matching (delegates to BracketMatcher)

    /// Finds matching braces/brackets/parentheses.
    public static func findMatchingBraces(in text: String, at position: Int) -> NSRange? {
        BracketMatcher.findMatchingBraces(in: text, at: position)
    }

    // MARK: - Syntax Analysis (delegates to SyntaxTreeParser)

    /// Parses text into a hierarchical syntax tree.
    public static func parseIntoSyntaxTree(_ text: String, language: Language) -> [SyntaxNode] {
        SyntaxTreeParser.parseIntoSyntaxTree(text, language: language)
    }

    /// Extracts all identifiers from text.
    public static func extractIdentifiers(from text: String, language: Language) -> [TextToken] {
        LanguagePatternDetector.extractIdentifiers(from: text, language: language)
    }
}

// MARK: - Backward Compatibility Extensions

extension TextParsingUtilities {
    /// Character type classification (for backward compatibility).
    public enum CharacterType {
        /// Alphabetic letter character.
        case letter
        /// Numeric digit character.
        case digit
        /// Underscore character (_).
        case underscore
        /// Whitespace character (space, tab, etc.).
        case whitespace
        /// Punctuation character.
        case punctuation
        /// Any other character type.
        case other
    }

    /// Classifies a character into a type category.
    public static func classifyCharacterType(_ char: Character) -> CharacterType {
        let result = TokenExtractor.classifyCharacterType(char)
        switch result {
        case .letter: return .letter
        case .digit: return .digit
        case .underscore: return .underscore
        case .whitespace: return .whitespace
        case .punctuation: return .punctuation
        case .other: return .other
        }
    }
}
