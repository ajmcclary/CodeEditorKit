import CodeEditorTextModel
import Foundation

/// C-style language symbol provider for C, C++, Java, Go, Rust
package struct CStyleSymbolProvider: LineBasedSymbolProvider {
    package init() {}

    package func detectSymbol(in line: String, at location: Int, lineIndex _: Int, fullLine: String) -> DocumentSymbol? {
        // Function detection (simplified)
        if line.contains("(") && line.contains(")") && !line.hasPrefix("//") && !line.hasPrefix("/*") {
            // Try to extract function name
            if let parenIndex = line.firstIndex(of: "(") {
                let beforeParen = line[..<parenIndex].trimmingCharacters(in: .whitespaces)
                let parts = beforeParen.split(separator: " ")
                if let lastPart = parts.last, !lastPart.isEmpty {
                    return DocumentSymbol(
                        name: String(lastPart),
                        kind: .function,
                        range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                        detail: fullLine
                    )
                }
            }
        }

        // Class/struct detection
        if line.hasPrefix("class ") || line.hasPrefix("struct ") {
            let prefix = line.hasPrefix("class ") ? "class" : "struct"
            return extractCStyleSymbol(from: line, prefix: prefix, kind: .class, at: location, fullLine: fullLine)
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
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: line
        )
    }
}
