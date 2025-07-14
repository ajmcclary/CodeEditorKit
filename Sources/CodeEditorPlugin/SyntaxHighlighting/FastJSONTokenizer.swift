import Foundation

// MARK: - String Extension for Character Access

// swiftlint:disable:next no_extension_access_modifier
private extension String {
    func unicharAt(_ index: Int) -> unichar {
        // swiftlint:disable:next legacy_objc_type
        let nsString = self as NSString
        return nsString.character(at: index)
    }
    
    func nsStringSubstring(with range: NSRange) -> String {
        // swiftlint:disable:next legacy_objc_type
        let nsString = self as NSString
        return nsString.substring(with: range)
    }
}

/// High-performance JSON tokenizer optimized for large files
/// Uses streaming parser approach to reduce memory usage and improve consistency
final class FastJSONTokenizer {
    // MARK: - Types
    
    enum TokenType {
        case openBrace      // {
        case closeBrace     // }
        case openBracket    // [
        case closeBracket   // ]
        case string         // "..."
        case number         // 123, -45.67
        case boolean        // true, false
        case null           // null
        case key            // "key":
        case comma          // ,
        case colon          // :
        case whitespace     // spaces, tabs, newlines
        case invalid        // parsing errors
    }
    
    struct Token {
        let type: TokenType
        let range: NSRange
        let value: String?
    }
    
    // MARK: - Properties
    
    private let chunkSize = 4_096 // Process JSON in 4KB chunks
    private var tokenCache = [NSRange: [Token]]()
    private let cacheLimit = 50 // Cache up to 50 chunks
    
    // MARK: - Public Methods
    
    /// Tokenize JSON content with stable performance
    func tokenize(_ text: String, in range: NSRange? = nil) -> [Token] {
        let targetRange = range ?? NSRange(location: 0, length: text.count)
        
        // Check cache first
        if let cachedTokens = tokenCache[targetRange] {
            return cachedTokens
        }
        
        // Process in chunks for consistent performance
        var tokens: [Token] = []
        let textString = text
        
        var currentPosition = targetRange.location
        let endPosition = targetRange.location + targetRange.length
        
        while currentPosition < endPosition {
            let remainingLength = endPosition - currentPosition
            let currentChunkSize = min(chunkSize, remainingLength)
            let chunkRange = NSRange(location: currentPosition, length: currentChunkSize)
            
            let chunkTokens = tokenizeChunk(textString, in: chunkRange)
            tokens.append(contentsOf: chunkTokens)
            
            currentPosition += currentChunkSize
        }
        
        // Cache the result
        maintainCacheSize()
        tokenCache[targetRange] = tokens
        
        return tokens
    }
    
    /// Get syntax highlighting attributes for tokens
    func highlightingAttributes(for tokens: [Token], colorScheme: SyntaxColorScheme) -> [(NSRange, [NSAttributedString.Key: Any])] {
        var attributes: [(NSRange, [NSAttributedString.Key: Any])] = []
        
        for token in tokens {
            let color: PlatformColor
            
            switch token.type {
            case .string:
                color = colorScheme.string

            case .number:
                color = colorScheme.number

            case .boolean, .null:
                color = colorScheme.keyword

            case .key:
                color = colorScheme.property

            case .openBrace, .closeBrace, .openBracket, .closeBracket:
                color = colorScheme.punctuation

            case .comma, .colon:
                color = colorScheme.punctuation

            case .invalid:
                color = colorScheme.error

            case .whitespace:
                continue // Don't highlight whitespace
            }
            
            attributes.append((token.range, [.foregroundColor: color]))
        }
        
        return attributes
    }
    
    /// Clear token cache
    func clearCache() {
        tokenCache.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func tokenizeChunk(_ text: String, in range: NSRange) -> [Token] {
        var tokens: [Token] = []
        var currentIndex = range.location
        let endIndex = range.location + range.length
        
        while currentIndex < endIndex {
            let char = text.unicharAt( currentIndex)
            let unicodeScalar = UnicodeScalar(char)!
            
            // Skip whitespace
            if CharacterSet.whitespacesAndNewlines.contains(unicodeScalar) {
                let wsStart = currentIndex
                while currentIndex < endIndex {
                    let character = UnicodeScalar(text.unicharAt( currentIndex))!
                    if !CharacterSet.whitespacesAndNewlines.contains(character) {
                        break
                    }
                    currentIndex += 1
                }
                tokens.append(Token(
                    type: .whitespace,
                    range: NSRange(location: wsStart, length: currentIndex - wsStart),
                    value: nil
                ))
                continue
            }
            
            // Handle different token types
            switch unicodeScalar {
            case "{":
                tokens.append(Token(type: .openBrace, range: NSRange(location: currentIndex, length: 1), value: nil))
                currentIndex += 1
                
            case "}":
                tokens.append(Token(type: .closeBrace, range: NSRange(location: currentIndex, length: 1), value: nil))
                currentIndex += 1
                
            case "[":
                tokens.append(Token(type: .openBracket, range: NSRange(location: currentIndex, length: 1), value: nil))
                currentIndex += 1
                
            case "]":
                tokens.append(Token(type: .closeBracket, range: NSRange(location: currentIndex, length: 1), value: nil))
                currentIndex += 1
                
            case ",":
                tokens.append(Token(type: .comma, range: NSRange(location: currentIndex, length: 1), value: nil))
                currentIndex += 1
                
            case ":":
                tokens.append(Token(type: .colon, range: NSRange(location: currentIndex, length: 1), value: nil))
                currentIndex += 1
                
            case "\"":
                // Parse string
                if let stringToken = parseString(text, startingAt: currentIndex, endIndex: endIndex) {
                    tokens.append(stringToken)
                    currentIndex = stringToken.range.location + stringToken.range.length
                } else {
                    tokens.append(Token(type: .invalid, range: NSRange(location: currentIndex, length: 1), value: nil))
                    currentIndex += 1
                }
                
            case "-", "0"..."9":
                // Parse number
                if let numberToken = parseNumber(text, startingAt: currentIndex, endIndex: endIndex) {
                    tokens.append(numberToken)
                    currentIndex = numberToken.range.location + numberToken.range.length
                } else {
                    tokens.append(Token(type: .invalid, range: NSRange(location: currentIndex, length: 1), value: nil))
                    currentIndex += 1
                }
                
            default:
                // Check for true, false, null
                if let literalToken = parseLiteral(text, startingAt: currentIndex, endIndex: endIndex) {
                    tokens.append(literalToken)
                    currentIndex = literalToken.range.location + literalToken.range.length
                } else {
                    tokens.append(Token(type: .invalid, range: NSRange(location: currentIndex, length: 1), value: nil))
                    currentIndex += 1
                }
            }
        }
        
        return tokens
    }
    
    private func parseString(_ text: String, startingAt index: Int, endIndex: Int) -> Token? {
        guard index < endIndex && text.unicharAt( index) == Character("\"").utf16.first! else {
            return nil
        }
        
        var currentIndex = index + 1
        var escaped = false
        
        while currentIndex < endIndex {
            let char = text.unicharAt( currentIndex)
            
            if escaped {
                escaped = false
            } else if char == Character("\\").utf16.first! {
                escaped = true
            } else if char == Character("\"").utf16.first! {
                // Found closing quote
                let range = NSRange(location: index, length: currentIndex - index + 1)
                let value = text.nsStringSubstring(with: NSRange(location: index + 1, length: currentIndex - index - 1))
                
                // Check if this is a key (followed by colon)
                var isKey = false
                var checkIndex = currentIndex + 1
                while checkIndex < endIndex {
                    let checkChar = UnicodeScalar(text.unicharAt( checkIndex))!
                    if CharacterSet.whitespacesAndNewlines.contains(checkChar) {
                        checkIndex += 1
                        continue
                    }
                    if checkChar == ":" {
                        isKey = true
                    }
                    break
                }
                
                return Token(type: isKey ? .key : .string, range: range, value: value)
            }
            
            currentIndex += 1
        }
        
        // Unterminated string
        return Token(type: .invalid, range: NSRange(location: index, length: endIndex - index), value: nil)
    }
    
    private func parseNumber(_ text: String, startingAt index: Int, endIndex: Int) -> Token? {
        var currentIndex = index
        
        // Handle negative sign
        if currentIndex < endIndex && text.unicharAt( currentIndex) == Character("-").utf16.first! {
            currentIndex += 1
        }
        
        // Must have at least one digit
        guard currentIndex < endIndex && CharacterSet.decimalDigits.contains(UnicodeScalar(text.unicharAt( currentIndex))!) else {
            return nil
        }
        
        // Parse integer part
        while currentIndex < endIndex && CharacterSet.decimalDigits.contains(UnicodeScalar(text.unicharAt( currentIndex))!) {
            currentIndex += 1
        }
        
        // Parse decimal part
        if currentIndex < endIndex && text.unicharAt( currentIndex) == Character(".").utf16.first! {
            currentIndex += 1
            
            // Must have at least one digit after decimal
            guard currentIndex < endIndex && CharacterSet.decimalDigits.contains(UnicodeScalar(text.unicharAt( currentIndex))!) else {
                return Token(type: .invalid, range: NSRange(location: index, length: currentIndex - index), value: nil)
            }
            
            while currentIndex < endIndex && CharacterSet.decimalDigits.contains(UnicodeScalar(text.unicharAt( currentIndex))!) {
                currentIndex += 1
            }
        }
        
        // Parse exponent part
        if currentIndex < endIndex {
            let char = text.unicharAt( currentIndex)
            if char == Character("e").utf16.first! || char == Character("E").utf16.first! {
                currentIndex += 1
                
                // Handle sign
                if currentIndex < endIndex {
                    let signChar = text.unicharAt( currentIndex)
                    if signChar == Character("+").utf16.first! || signChar == Character("-").utf16.first! {
                        currentIndex += 1
                    }
                }
                
                // Must have at least one digit
                guard currentIndex < endIndex && CharacterSet.decimalDigits.contains(UnicodeScalar(text.unicharAt( currentIndex))!) else {
                    return Token(type: .invalid, range: NSRange(location: index, length: currentIndex - index), value: nil)
                }
                
                while currentIndex < endIndex && CharacterSet.decimalDigits.contains(UnicodeScalar(text.unicharAt( currentIndex))!) {
                    currentIndex += 1
                }
            }
        }
        
        let range = NSRange(location: index, length: currentIndex - index)
        let value = text.nsStringSubstring(with: range)
        return Token(type: .number, range: range, value: value)
    }
    
    private func parseLiteral(_ text: String, startingAt index: Int, endIndex: Int) -> Token? {
        let literals = ["true", "false", "null"]
        
        for literal in literals {
            let literalLength = literal.count
            if index + literalLength <= endIndex {
                let range = NSRange(location: index, length: literalLength)
                let substring = text.nsStringSubstring(with: range)
                
                if substring == literal {
                    // Check that it's not part of a larger word
                    if index + literalLength < endIndex {
                        let nextChar = UnicodeScalar(text.unicharAt( index + literalLength))!
                        if CharacterSet.alphanumerics.contains(nextChar) {
                            return nil
                        }
                    }
                    
                    let type: TokenType = (literal == "true" || literal == "false") ? .boolean : .null
                    return Token(type: type, range: range, value: literal)
                }
            }
        }
        
        return nil
    }
    
    private func maintainCacheSize() {
        if tokenCache.count >= cacheLimit {
            // Remove oldest entries (simple FIFO for now)
            let entriesToRemove = tokenCache.count - cacheLimit + 1
            let sortedKeys = tokenCache.keys.sorted { $0.location < $1.location }
            
            for index in 0..<entriesToRemove {
                tokenCache.removeValue(forKey: sortedKeys[index])
            }
        }
    }
}
