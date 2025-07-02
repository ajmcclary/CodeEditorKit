import Foundation

/// YAML symbol provider for detecting YAML structure and keys
struct YAMLSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        var indentationStack: [(level: Int, symbol: DocumentSymbol)] = []
        
        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectYAMLSymbol(in: line, at: currentLocation, line: lineIndex) {
                // Calculate indentation level
                let indentLevel = line.prefix { $0.isWhitespace }.count
                
                // Pop symbols from stack that are at same or deeper level
                while let lastItem = indentationStack.last, lastItem.level >= indentLevel {
                    indentationStack.removeLast()
                }
                
                // Add symbol to appropriate parent
                var symbolToAdd = symbol
                if !indentationStack.isEmpty {
                    // This would be a child symbol - in a more complete implementation,
                    // we'd modify the parent's children array
                    symbolToAdd.detail = "\(symbol.detail ?? "") (level \(indentLevel))"
                }
                
                symbols.append(symbolToAdd)
                
                // Add to stack if it might have children
                if symbol.kind.canContainSymbols || indentLevel == 0 {
                    indentationStack.append((level: indentLevel, symbol: symbolToAdd))
                }
            }
            
            currentLocation += line.count + 1
        }
        
        return symbols
    }
    
    private func detectYAMLSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Skip comments and empty lines
        if trimmed.hasPrefix("#") || trimmed.isEmpty {
            return nil
        }
        
        // Detect YAML document separators
        if trimmed == "---" || trimmed == "..." {
            return DocumentSymbol(
                name: trimmed,
                kind: .module,
                range: NSRange(location: location, length: line.count),
                detail: "Document separator"
            )
        }
        
        // Detect array items
        if trimmed.hasPrefix("- ") {
            let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if content.contains(":") {
                // Array item with nested object
                return extractYAMLKey(from: content, at: location, fullLine: line, isArrayItem: true)
            } else {
                return DocumentSymbol(
                    name: content.isEmpty ? "[item]" : content,
                    kind: .enumMember,
                    range: NSRange(location: location, length: line.count),
                    detail: "Array item"
                )
            }
        }
        
        // Detect key-value pairs
        if trimmed.contains(":") {
            return extractYAMLKey(from: trimmed, at: location, fullLine: line, isArrayItem: false)
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
            range: NSRange(location: location, length: fullLine.count),
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
