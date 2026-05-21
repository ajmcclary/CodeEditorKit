import CodeEditorTextModel
import Foundation

/// YAML symbol provider for detecting YAML structure and keys
package struct YAMLSymbolProvider: StatefulLineBasedSymbolProvider {
    package typealias State = [(level: Int, symbol: DocumentSymbol)] // indentation stack

    package init() {}

    package func makeState() -> State { [] }

    package func detectSymbols(
        in line: String,
        at location: Int,
        lineIndex _: Int,
        fullLine: String,
        state: inout State
    ) -> [DocumentSymbol] {
        guard let symbol = detectYAMLSymbol(in: line, at: location, fullLine: fullLine) else {
            return []
        }

        // Calculate indentation level from the raw line (state is indent-driven).
        let indentLevel = fullLine.prefix { $0.isWhitespace }.count

        // Pop symbols from stack that are at same or deeper level.
        while let lastItem = state.last, lastItem.level >= indentLevel {
            state.removeLast()
        }

        // Tag children with their nesting level for now (existing behavior).
        var symbolToAdd = symbol
        if !state.isEmpty {
            symbolToAdd.detail = "\(symbol.detail ?? "") (level \(indentLevel))"
        }

        // Push onto the stack if this symbol can contain children.
        if symbol.kind.canContainSymbols || indentLevel == 0 {
            state.append((level: indentLevel, symbol: symbolToAdd))
        }

        return [symbolToAdd]
    }

    private func detectYAMLSymbol(in line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Skip comments and empty lines
        if line.hasPrefix("#") || line.isEmpty {
            return nil
        }

        // Detect YAML document separators
        if line == "---" || line == "..." {
            return DocumentSymbol(
                name: line,
                kind: .module,
                range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                detail: "Document separator"
            )
        }

        // Detect array items
        if line.hasPrefix("- ") {
            let content = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if content.contains(":") {
                // Array item with nested object
                return extractYAMLKey(from: content, at: location, fullLine: fullLine, isArrayItem: true)
            } else {
                return DocumentSymbol(
                    name: content.isEmpty ? "[item]" : content,
                    kind: .enumMember,
                    range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                    detail: "Array item"
                )
            }
        }

        // Detect key-value pairs
        if line.contains(":") {
            return extractYAMLKey(from: line, at: location, fullLine: fullLine, isArrayItem: false)
        }

        return nil
    }

    private func extractYAMLKey(from line: String, at location: Int, fullLine: String, isArrayItem: Bool) -> DocumentSymbol? {
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }

        let key = String(line.prefix(upTo: colonIndex)).trimmingCharacters(in: .whitespaces)
        let value = String(line.suffix(from: line.index(after: colonIndex))).trimmingCharacters(in: .whitespaces)

        guard !key.isEmpty else { return nil }

        let kind = yamlValueKind(for: value)
        let detail = yamlValueDetail(for: value)

        let displayName = isArrayItem ? "- \(key)" : key

        return DocumentSymbol(
            name: displayName,
            kind: kind,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: detail
        )
    }

    private func yamlValueKind(for value: String) -> DocumentSymbolKind {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        // Empty value - might be an object with children
        if trimmed.isEmpty {
            return .object
        }

        // Array indicator
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            return .array
        }

        // Quoted string
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return .string
        }

        // Boolean values
        if ["true", "false", "yes", "no", "on", "off"].contains(trimmed.lowercased()) {
            return .boolean
        }

        // Null values
        if ["null", "~", ""].contains(trimmed.lowercased()) {
            return .null
        }

        // Number
        if Double(trimmed) != nil || Int(trimmed) != nil {
            return .number
        }

        // Block scalar indicators
        if trimmed == "|" || trimmed == ">" {
            return .string
        }

        // Reference (YAML anchor or alias)
        if trimmed.hasPrefix("&") || trimmed.hasPrefix("*") {
            return .key
        }

        // Default to string
        return .string
    }

    private func yamlValueDetail(for value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return "object"
        }

        if trimmed.count > 50 {
            return String(trimmed.prefix(50)) + "..."
        }

        return trimmed
    }
}
