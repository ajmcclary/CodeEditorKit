import Foundation

// MARK: - Completion Context Extractor

/// Service responsible for extracting completion context from text
@MainActor
internal final class CompletionContextExtractor {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "CompletionContextExtractor")

    // MARK: - Public Methods

    /// Extracts completion context at the given location
    internal func extractContext(
        at location: Int,
        in text: String,
        language: Language
    ) -> CompletionContext {
        guard location >= 0 && location <= TextRangeUtilities.utf16Length(of: text) else {
            return createEmptyContext(at: location, language: language)
        }

        // Extract current line
        let (currentLine, currentLineIndex, _) = extractCurrentLine(at: location, in: text)

        // Extract prefix (word being typed)
        let prefix = extractPrefix(at: location, in: text)

        // Determine trigger character
        let triggerCharacter = extractTriggerCharacter(at: location, in: text)

        // Calculate context range (surrounding text for better context)
        let contextRange = calculateContextRange(at: location, in: text)

        logger.debug("Extracted context - prefix: '\(prefix)', trigger: '\(triggerCharacter ?? "none")', line: \(currentLineIndex)")

        return CompletionContext(
            triggerLocation: location,
            triggerCharacter: triggerCharacter,
            prefix: prefix,
            currentLine: currentLine,
            language: language,
            contextRange: contextRange
        )
    }

    /// Extracts the prefix (word being typed) at the given location
    internal func extractPrefix(at location: Int, in text: String) -> String {
        TextRangeUtilities.identifierPrefix(endingAtUTF16Offset: location, in: text)
    }

    /// Checks if completion should be triggered at the given location
    internal func shouldTriggerCompletion(at location: Int, in text: String) -> Bool {
        guard location > 0 && location <= TextRangeUtilities.utf16Length(of: text),
              let character = TextRangeUtilities.characterBeforeUTF16Offset(location, in: text)
        else { return false }

        // Check trigger characters
        let triggerCharacters = [".", " ", "(", "[", "{", ":", ",", "<", "=", ">"]
        return triggerCharacters.contains(String(character))
    }

    // MARK: - Private Methods

    private func createEmptyContext(at location: Int, language: Language) -> CompletionContext {
        CompletionContext(
            triggerLocation: location,
            triggerCharacter: nil,
            prefix: "",
            currentLine: "",
            language: language,
            contextRange: NSRange(location: 0, length: 0)
        )
    }

    private func extractCurrentLine(at location: Int, in text: String) -> (line: String, index: Int, start: Int) {
        let prefix = TextRangeUtilities.substring(upToUTF16Offset: location, in: text)
        let currentLineIndex = max(0, prefix.components(separatedBy: .newlines).count - 1)
        let lineRange = TextRangeUtilities.lineRange(containingUTF16Offset: location, in: text)
        let currentLine = TextRangeUtilities.lineText(containingUTF16Offset: location, in: text)
        return (currentLine, currentLineIndex, lineRange.location)
    }

    private func extractTriggerCharacter(at location: Int, in text: String) -> String? {
        guard location > 0,
              let character = TextRangeUtilities.characterBeforeUTF16Offset(location, in: text)
        else { return nil }

        return String(character)
    }

    private func calculateContextRange(at location: Int, in text: String) -> NSRange {
        let contextBefore = 100
        let contextAfter = 100
        let textLength = TextRangeUtilities.utf16Length(of: text)

        let start = max(0, location - contextBefore)
        let length = min(contextBefore + contextAfter, textLength - start)

        return NSRange(location: start, length: length)
    }
}
