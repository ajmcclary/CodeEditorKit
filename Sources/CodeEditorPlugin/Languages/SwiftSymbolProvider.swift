import Foundation

/// Swift symbol provider for detecting Swift classes, structs, enums, functions, and properties
struct SwiftSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Simple pattern matching for Swift
            if let symbol = detectSwiftSymbol(in: trimmed, at: currentLocation, line: lineIndex, fullLine: line) {
                symbols.append(symbol)
            }

            currentLocation += line.count + 1 // +1 for newline
        }

        return symbols
    }

    private func detectSwiftSymbol(in line: String, at location: Int, line _: Int, fullLine: String) -> DocumentSymbol? {
        // Class detection
        if line.hasPrefix("class ") || line.hasPrefix("final class ") {
            return extractSymbol(from: line, prefix: "class", kind: .class, at: location, fullLine: fullLine)
        }

        // Struct detection
        if line.hasPrefix("struct ") {
            return extractSymbol(from: line, prefix: "struct", kind: .struct, at: location, fullLine: fullLine)
        }

        // Enum detection
        if line.hasPrefix("enum ") {
            return extractSymbol(from: line, prefix: "enum", kind: .enum, at: location, fullLine: fullLine)
        }

        // Protocol detection
        if line.hasPrefix("protocol ") {
            return extractSymbol(from: line, prefix: "protocol", kind: .interface, at: location, fullLine: fullLine)
        }

        // Function detection
        if line.hasPrefix("func ") || line.contains(" func ") {
            let prefix = line.hasPrefix("func ") ? "func" : String(line.prefix { $0 != "f" }) + "func"
            return extractSymbol(from: line, prefix: prefix, kind: .function, at: location, fullLine: fullLine)
        }

        // Property detection
        if line.hasPrefix("var ") || line.hasPrefix("let ") {
            let prefix = line.hasPrefix("var ") ? "var" : "let"
            let kind: DocumentSymbolKind = line.hasPrefix("let ") ? .constant : .variable
            return extractSymbol(from: line, prefix: prefix, kind: kind, at: location, fullLine: fullLine)
        }

        return nil
    }

    private func extractSymbol(from line: String, prefix: String, kind: DocumentSymbolKind, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Extract name after prefix
        let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let name = afterPrefix.prefix { $0.isLetter || $0.isNumber || $0 == "_" }

        guard !name.isEmpty else { return nil }

        // Calculate selection range (just the name)
        let nameStart = fullLine.range(of: String(name))?.lowerBound
        let selectionStart = nameStart.map { fullLine.distance(from: fullLine.startIndex, to: $0) } ?? 0

        return DocumentSymbol(
            name: String(name),
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            selectionRange: NSRange(location: location + selectionStart, length: name.count),
            detail: line
        )
    }
}
