import Foundation

// MARK: - Text Processing Utilities Hub

/// Unified hub for common text processing operations across the codebase
/// Consolidates 25+ duplicate implementations scattered across multiple files
public enum TextProcessingUtilities {
    // MARK: - Supporting Types

    /// Modes for extracting words from text with different boundary detection strategies.
    public enum WordExtractionMode {
        /// Standard word boundaries using alphanumeric characters and underscores.
        case standard
        /// Programming identifiers including $ for JavaScript support.
        case identifier
        /// Split words on camelCase boundaries for compound identifiers.
        case camelCase
        /// Split words on snake_case boundaries.
        case snakeCase
        /// Split only on whitespace characters, preserving all other text.
        case whitespace
    }

    /// Classification categories for individual characters in text processing.
    public enum CharacterClass {
        /// Alphanumeric characters (letters and digits).
        case alphanumeric
        /// Whitespace characters including spaces and tabs.
        case whitespace
        /// Punctuation marks and symbols used in writing.
        case punctuation
        /// Mathematical and other symbolic characters.
        case symbol
        /// Numeric digit characters.
        case digit
        /// Alphabetic letter characters.
        case letter
        /// Characters valid in programming language identifiers.
        case identifier
        /// Newline characters for line termination.
        case newline
        /// Tab characters for indentation.
        case tab
        /// Characters that don't fit other categories.
        case unknown
    }

    public enum TrimmingMode: Sendable {
        case leading
        case trailing
        case leadingAndTrailing
        case `internal`          // Collapse multiple spaces to single
        case all              // Remove all whitespace
    }

    /// Line ending format options for text normalization operations.
    public enum LineEndingFormat {
        /// Unix-style line endings using LF (\n).
        case unix
        /// Windows-style line endings using CRLF (\r\n).
        case windows
        /// Classic Mac-style line endings using CR (\r).
        case classic
        /// Preserve existing mixed line ending formats.
        case mixed
    }

    /// Analysis results for text complexity measurement and processing cost estimation.
    public struct TextComplexity {
        /// Total number of lines in the text.
        public let lineCount: Int
        /// Average character count per line.
        public let averageLineLength: Int
        /// Maximum character count in any single line.
        public let maxLineLength: Int
        /// Count of unique characters used in the text.
        public let uniqueCharacterCount: Int
        /// Maximum nesting depth of brackets, braces, and parentheses.
        public let nestingDepth: Int
        /// Whether the text contains only ASCII characters.
        public let isASCII: Bool

        /// Calculated complexity score from 0.0 to 1.0+ based on various text metrics.
        public var complexityScore: Double {
            let factors = [
                Double(lineCount) / 1_000.0,
                Double(maxLineLength) / 120.0,
                Double(nestingDepth) / 10.0,
                isASCII ? 0.0 : 0.5
            ]
            return factors.reduce(0, +) / Double(factors.count)
        }
    }

    public struct ProcessingCost: Sendable {
        public let estimatedTimeMs: Double
        public let memoryRequirementMB: Double
        public let cpuIntensity: CPUIntensity

        public enum CPUIntensity: Sendable {
            case low, medium, high, extreme
        }
    }

    /// A token extracted from text with type classification and position information.
    public struct TextToken {
        /// The actual text content of this token.
        public let text: String
        /// The range of this token within the source text.
        public let range: NSRange
        /// The classification type of this token.
        public let type: TokenType

        /// Categories for classifying extracted text tokens.
        public enum TokenType {
            /// Regular word tokens composed of letters.
            case word
            /// Programming language identifiers.
            case identifier
            /// Numeric literal tokens.
            case number
            /// String literal tokens.
            case string
            /// Comment tokens.
            case comment
            /// Operator and punctuation tokens.
            case `operator`
            /// Whitespace tokens including spaces and tabs.
            case whitespace
        }
    }

    // MARK: - Text Manipulation

    /// Extracts words from text using specified extraction mode
    /// Consolidates word extraction logic from FuzzyMatcher and CompletionParsingHelpers
    public static func extractWords(from text: String, mode: WordExtractionMode = .standard) -> [String] {
        switch mode {
        case .standard:
            return text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
                .filter { !$0.isEmpty }

        case .identifier:
            return text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$")).inverted)
                .filter { !$0.isEmpty }

        case .camelCase:
            return splitCamelCase(text)

        case .snakeCase:
            return text.components(separatedBy: "_").filter { !$0.isEmpty }

        case .whitespace:
            return text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        }
    }

    /// Extracts the current word at the end of text (cursor position)
    /// Consolidates logic from CompletionParsingHelpers
    public static func extractCurrentWord(from text: String) -> String {
        guard !text.isEmpty else { return "" }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = extractWords(from: trimmed, mode: .identifier)
        return words.last ?? ""
    }

    /// Extracts current programming identifier (more strict than word)
    public static func extractCurrentIdentifier(from text: String) -> String {
        guard !text.isEmpty else { return "" }

        let identifierSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$"))

        // Find the longest valid identifier at the end of the text
        let endIndex = text.endIndex
        var startIndex = text.endIndex

        // Walk backwards from the end
        for char in text.reversed() {
            guard let firstScalar = char.unicodeScalars.first else { break }
            if identifierSet.contains(firstScalar) {
                startIndex = text.index(before: startIndex)
            } else {
                break
            }
        }

        return String(text[startIndex..<endIndex])
    }

    /// Splits text into processing chunks with offset tracking
    /// Consolidates chunking logic from AsyncTextProcessor and BackgroundSyntaxHighlighter
    public static func splitIntoChunks(_ text: String, chunkSize: Int) -> [(text: String, offset: Int)] {
        guard !text.isEmpty && chunkSize > 0 else { return [] }

        var chunks: [(text: String, offset: Int)] = []
        var currentOffset = 0

        let lines = text.components(separatedBy: .newlines)
        var currentChunk = ""
        var chunkOffset = 0

        for line in lines {
            let lineWithNewline = line + "\n"

            if currentChunk.count + lineWithNewline.count > chunkSize && !currentChunk.isEmpty {
                // Complete current chunk
                chunks.append((text: currentChunk, offset: chunkOffset))

                // Start new chunk
                currentChunk = lineWithNewline
                chunkOffset = currentOffset
            } else {
                if currentChunk.isEmpty {
                    chunkOffset = currentOffset
                }
                currentChunk += lineWithNewline
            }

            currentOffset += lineWithNewline.count
        }

        // Add final chunk if not empty
        if !currentChunk.isEmpty {
            chunks.append((text: currentChunk, offset: chunkOffset))
        }

        return chunks
    }

    // MARK: - Character Operations

    /// Classifies a character into its functional category
    public static func classifyCharacter(_ char: Character) -> CharacterClass {
        guard let scalar = char.unicodeScalars.first else {
            return .unknown
        }

        if char.isNewline {
            return .newline
        }

        if char == "\t" {
            return .tab
        }

        if char.isWhitespace {
            return .whitespace
        }

        if char.isNumber {
            return .digit
        }

        if char.isLetter {
            return .letter
        }

        if CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$")).contains(scalar) {
            return .identifier
        }

        if CharacterSet.punctuationCharacters.contains(scalar) {
            return .punctuation
        }

        if CharacterSet.symbols.contains(scalar) {
            return .symbol
        }

        return .unknown
    }

    /// Trims whitespace according to specified mode
    public static func trimWhitespace(from text: String, mode: TrimmingMode = .leadingAndTrailing) -> String {
        switch mode {
        case .leading:
            return String(text.drop { $0.isWhitespace })

        case .trailing:
            return String(text.reversed().drop { $0.isWhitespace }.reversed())

        case .leadingAndTrailing:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)

        case .`internal`:
            return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        case .all:
            return text.filter { !$0.isWhitespace }
        }
    }

    /// Normalizes whitespace (converts tabs to spaces, normalizes line endings)
    public static func normalizeWhitespace(in text: String, tabWidth: Int = 4) -> String {
        let tabReplacement = String(repeating: " ", count: tabWidth)
        return text.replacingOccurrences(of: "\t", with: tabReplacement)
    }

    // MARK: - Text Analysis

    /// Analyzes text complexity for processing cost estimation
    public static func analyzeTextComplexity(_ text: String) -> TextComplexity {
        let lines = text.components(separatedBy: .newlines)
        let lineCount = lines.count
        let averageLineLength = lineCount > 0 ? text.count / lineCount : 0
        let maxLineLength = lines.map(\.count).max() ?? 0
        let uniqueCharacterCount = Set(text).count
        let nestingDepth = calculateNestingDepth(text)
        let isASCII = text.allSatisfy { $0.isASCII }

        return TextComplexity(
            lineCount: lineCount,
            averageLineLength: averageLineLength,
            maxLineLength: maxLineLength,
            uniqueCharacterCount: uniqueCharacterCount,
            nestingDepth: nestingDepth,
            isASCII: isASCII
        )
    }

    /// Estimates processing cost for a given operation
    public static func estimateProcessingCost(for text: String, operation: TextProcessingOperationType) -> ProcessingCost {
        let complexity = analyzeTextComplexity(text)
        let textSize = text.utf8.count

        let (timeMs, memoryMB, intensity) = operation.estimateCost(textSize: textSize, complexity: complexity)

        return ProcessingCost(
            estimatedTimeMs: timeMs,
            memoryRequirementMB: memoryMB,
            cpuIntensity: intensity
        )
    }

    // MARK: - Line Processing

    /// Finds word boundaries within text
    public static func findWordBoundaries(in text: String) -> [Int] {
        var boundaries: [Int] = [0] // Start of text
        var index = 0
        var wasWord = false

        for char in text {
            let isWord = char.isLetter || char.isNumber || char == "_"

            if isWord != wasWord {
                boundaries.append(index)
            }

            wasWord = isWord
            index += 1
        }

        if index > 0 {
            boundaries.append(index) // End of text
        }

        return boundaries
    }

    /// Extracts indentation information from a line
    public static func extractLineIndentation(_ line: String) -> (spaces: Int, tabs: Int) {
        var spaces = 0
        var tabs = 0

        for char in line {
            if char == " " {
                spaces += 1
            } else if char == "\t" {
                tabs += 1
            } else {
                break // First non-whitespace character
            }
        }

        return (spaces: spaces, tabs: tabs)
    }

    /// Normalizes line endings to specified format
    public static func normalizeLineEndings(in text: String, to format: LineEndingFormat) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
                             .replacingOccurrences(of: "\r", with: "\n")

        switch format {
        case .unix:
            return normalized

        case .windows:
            return normalized.replacingOccurrences(of: "\n", with: "\r\n")

        case .classic:
            return normalized.replacingOccurrences(of: "\n", with: "\r")

        case .mixed:
            return text // Keep original
        }
    }
}

// MARK: - Processing Operation Types

/// Types of text processing operations with different performance characteristics.
public enum TextProcessingOperationType {
    /// Syntax highlighting operations for code display.
    case syntaxHighlighting
    /// Code completion and suggestion operations.
    case completion
    /// Text validation and error checking operations.
    case validation
    /// Text search and pattern matching operations.
    case searching
    /// Text formatting and beautification operations.
    case formatting
    /// Text parsing and structure analysis operations.
    case parsing

    func estimateCost(textSize: Int, complexity: TextProcessingUtilities.TextComplexity) -> (timeMs: Double, memoryMB: Double, intensity: TextProcessingUtilities.ProcessingCost.CPUIntensity) {
        let sizeFactor = Double(textSize) / 1_000.0 // Per KB
        let complexityFactor = complexity.complexityScore

        switch self {
        case .syntaxHighlighting:
            return (
                timeMs: sizeFactor * 0.5 * (1 + complexityFactor),
                memoryMB: sizeFactor * 0.1,
                intensity: sizeFactor > 100 ? .high : .medium
            )

        case .completion:
            return (
                timeMs: 10 + sizeFactor * 0.1,
                memoryMB: 0.5 + sizeFactor * 0.05,
                intensity: .medium
            )

        case .validation:
            return (
                timeMs: sizeFactor * 0.2,
                memoryMB: sizeFactor * 0.02,
                intensity: .low
            )

        case .searching:
            return (
                timeMs: sizeFactor * 0.3,
                memoryMB: sizeFactor * 0.03,
                intensity: .medium
            )

        case .formatting:
            return (
                timeMs: sizeFactor * 0.4,
                memoryMB: sizeFactor * 0.05,
                intensity: .medium
            )

        case .parsing:
            return (
                timeMs: sizeFactor * 0.8 * (1 + complexityFactor),
                memoryMB: sizeFactor * 0.15,
                intensity: sizeFactor > 50 ? .high : .medium
            )
        }
    }
}

// MARK: - Private Helpers

extension TextProcessingUtilities {
    static func splitCamelCase(_ text: String) -> [String] {
        var words: [String] = []
        var currentWord = ""

        for char in text {
            if char.isUppercase && !currentWord.isEmpty {
                words.append(currentWord)
                currentWord = String(char)
            } else {
                currentWord.append(char)
            }
        }

        if !currentWord.isEmpty {
            words.append(currentWord)
        }

        return words
    }

    static func calculateNestingDepth(_ text: String) -> Int {
        var maxDepth = 0
        var currentDepth = 0

        for char in text {
            switch char {
            case "{", "[", "(":
                currentDepth += 1
                maxDepth = max(maxDepth, currentDepth)

            case "}", "]", ")":
                currentDepth = max(0, currentDepth - 1)

            default:
                break
            }
        }

        return maxDepth
    }
}
