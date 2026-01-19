import Foundation

// MARK: - Line-Based Symbol Provider Protocol

/// Protocol for symbol providers that detect symbols by iterating through lines
///
/// This protocol provides a default implementation of the `detectSymbols(in:)` method
/// that handles line iteration, location tracking, and symbol accumulation. Language-specific
/// providers only need to implement the `detectSymbol(in:at:lineIndex:fullLine:)` method.
///
/// ## Usage Example
///
/// ```swift
/// struct MyLanguageSymbolProvider: LineBasedSymbolProvider {
///     func detectSymbol(in line: String, at location: Int, lineIndex: Int, fullLine: String) -> DocumentSymbol? {
///         if line.hasPrefix("function ") {
///             return extractFunctionSymbol(from: line, at: location, fullLine: fullLine)
///         }
///         return nil
///     }
/// }
/// ```
///
/// ## Benefits
///
/// 1. **Reduced Boilerplate**: Common iteration logic is implemented once
/// 2. **Consistent Behavior**: All line-based providers use the same iteration pattern
/// 3. **Location Tracking**: Automatic tracking of character offsets
/// 4. **Easy Migration**: Existing providers can adopt with minimal changes
///
public protocol LineBasedSymbolProvider: DocumentSymbolProvider {
    /// Detect a symbol on a single line of code
    ///
    /// - Parameters:
    ///   - line: The trimmed line content (whitespace removed)
    ///   - location: The character offset from the start of the text
    ///   - lineIndex: The zero-based line index
    ///   - fullLine: The original line with whitespace preserved
    /// - Returns: A `DocumentSymbol` if one is detected, `nil` otherwise
    func detectSymbol(in line: String, at location: Int, lineIndex: Int, fullLine: String) -> DocumentSymbol?
}

// MARK: - Default Implementation

extension LineBasedSymbolProvider {
    /// Default implementation that iterates through lines and collects detected symbols
    public func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if let symbol = detectSymbol(in: trimmedLine, at: currentLocation, lineIndex: lineIndex, fullLine: line) {
                symbols.append(symbol)
            }

            currentLocation += line.count + 1 // +1 for newline
        }

        return symbols
    }
}

// MARK: - Utility Methods for Symbol Providers

extension LineBasedSymbolProvider {
    /// Extract a symbol name from a line after a given prefix
    ///
    /// - Parameters:
    ///   - line: The line to parse
    ///   - prefix: The prefix to skip (e.g., "class", "func")
    ///   - kind: The symbol kind
    ///   - location: The character offset
    ///   - fullLine: The original full line
    ///   - validChars: Additional valid characters for the name (default: "_")
    /// - Returns: A `DocumentSymbol` if a valid name is found
    public func extractSymbol(
        from line: String,
        prefix: String,
        kind: DocumentSymbolKind,
        at location: Int,
        fullLine: String,
        validChars: String = "_"
    ) -> DocumentSymbol? {
        let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let validCharSet = CharacterSet(charactersIn: validChars)
        let name = afterPrefix.prefix { char in
            char.isLetter || char.isNumber || char.unicodeScalars.first.map { validCharSet.contains($0) } ?? false
        }

        guard !name.isEmpty else { return nil }

        return DocumentSymbol(
            name: String(name),
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            detail: line
        )
    }

    /// Extract a symbol name from a line after a given prefix, with selection range
    ///
    /// - Parameters:
    ///   - line: The line to parse
    ///   - prefix: The prefix to skip
    ///   - kind: The symbol kind
    ///   - location: The character offset
    ///   - fullLine: The original full line
    ///   - validChars: Additional valid characters for the name
    /// - Returns: A `DocumentSymbol` with selection range if a valid name is found
    public func extractSymbolWithSelectionRange(
        from line: String,
        prefix: String,
        kind: DocumentSymbolKind,
        at location: Int,
        fullLine: String,
        validChars: String = "_"
    ) -> DocumentSymbol? {
        let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let validCharSet = CharacterSet(charactersIn: validChars)
        let name = afterPrefix.prefix { char in
            char.isLetter || char.isNumber || char.unicodeScalars.first.map { validCharSet.contains($0) } ?? false
        }

        guard !name.isEmpty else { return nil }

        // Calculate selection range
        let nameString = String(name)
        let nameStart = fullLine.range(of: nameString)?.lowerBound
        let selectionStart = nameStart.map { fullLine.distance(from: fullLine.startIndex, to: $0) } ?? 0

        return DocumentSymbol(
            name: nameString,
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            selectionRange: NSRange(location: location + selectionStart, length: name.count),
            detail: line
        )
    }
}
