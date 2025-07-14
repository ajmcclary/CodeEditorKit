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
        guard location <= text.count else {
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
        guard location > 0 else { return "" }
        
        var prefixStart = location
        let characterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        
        for charIndex in stride(from: location - 1, through: 0, by: -1) {
            let index = text.index(text.startIndex, offsetBy: charIndex)
            let character = text[index]
            
            if character.unicodeScalars.allSatisfy({ characterSet.contains($0) }) {
                prefixStart = charIndex
            } else {
                break
            }
        }
        
        if prefixStart < location {
            let startIndex = text.index(text.startIndex, offsetBy: prefixStart)
            let endIndex = text.index(text.startIndex, offsetBy: location)
            return String(text[startIndex..<endIndex])
        }
        
        return ""
    }
    
    /// Checks if completion should be triggered at the given location
    internal func shouldTriggerCompletion(at location: Int, in text: String) -> Bool {
        guard location > 0 && location <= text.count else { return false }
        
        let index = text.index(text.startIndex, offsetBy: location - 1)
        let character = String(text[index])
        
        // Check trigger characters
        let triggerCharacters = [".", " ", "(", "[", "{", ":", ",", "<", "=", ">"]
        return triggerCharacters.contains(character)
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
        let lines = text.components(separatedBy: .newlines)
        var currentLineIndex = 0
        var currentLineStart = 0
        
        for (index, line) in lines.enumerated() {
            let lineEnd = currentLineStart + line.count
            if location <= lineEnd {
                currentLineIndex = index
                break
            }
            currentLineStart = lineEnd + 1 // +1 for newline
        }
        
        let currentLine = currentLineIndex < lines.count ? lines[currentLineIndex] : ""
        return (currentLine, currentLineIndex, currentLineStart)
    }
    
    private func extractTriggerCharacter(at location: Int, in text: String) -> String? {
        guard location > 0 else { return nil }
        
        let index = text.index(text.startIndex, offsetBy: location - 1)
        return String(text[index])
    }
    
    private func calculateContextRange(at location: Int, in text: String) -> NSRange {
        let contextBefore = 100
        let contextAfter = 100
        
        let start = max(0, location - contextBefore)
        let length = min(contextBefore + contextAfter, text.count - start)
        
        return NSRange(location: start, length: length)
    }
}
