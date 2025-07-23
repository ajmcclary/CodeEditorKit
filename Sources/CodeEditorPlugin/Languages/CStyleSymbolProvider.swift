import Foundation

/// C-style language symbol provider for C, C++, Java, Go, Rust
struct CStyleSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectCStyleSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }

            currentLocation += line.count + 1
        }

        return symbols
    }

    private func detectCStyleSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Function detection (simplified)
        if trimmed.contains("(") && trimmed.contains(")") && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") {
            // Try to extract function name
            if let parenIndex = trimmed.firstIndex(of: "(") {
                let beforeParen = trimmed[..<parenIndex].trimmingCharacters(in: .whitespaces)
                let parts = beforeParen.split(separator: " ")
                if let lastPart = parts.last, !lastPart.isEmpty {
                    return DocumentSymbol(
                        name: String(lastPart),
                        kind: .function,
                        range: NSRange(location: location, length: line.count),
                        detail: line
                    )
                }
            }
        }

        // Class/struct detection
        if trimmed.hasPrefix("class ") || trimmed.hasPrefix("struct ") {
            let prefix = trimmed.hasPrefix("class ") ? "class" : "struct"
            return extractCStyleSymbol(from: trimmed, prefix: prefix, kind: .class, at: location, fullLine: line)
        }

        return nil
    }

    private func extractCStyleSymbol(from line: String, prefix: String, kind: DocumentSymbolKind, at location: Int, fullLine: String) -> DocumentSymbol? {
        let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let name = afterPrefix.prefix { $0.isLetter || $0.isNumber || $0 == "_" }

        guard !name.isEmpty else { return nil }

        return DocumentSymbol(
            name: String(name),
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            detail: line
        )
    }
}
