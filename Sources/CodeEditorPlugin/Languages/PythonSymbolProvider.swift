import Foundation

/// Python symbol provider for detecting Python classes, functions, and methods
struct PythonSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectPythonSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }

            currentLocation += line.count + 1
        }

        return symbols
    }

    private func detectPythonSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Class detection
        if trimmed.hasPrefix("class ") {
            return extractPythonSymbol(from: trimmed, prefix: "class", kind: .class, at: location, fullLine: line)
        }

        // Function detection
        if trimmed.hasPrefix("def ") || trimmed.hasPrefix("async def ") {
            let prefix = trimmed.hasPrefix("async def ") ? "async def" : "def"
            return extractPythonSymbol(from: trimmed, prefix: prefix, kind: .function, at: location, fullLine: line)
        }

        return nil
    }

    private func extractPythonSymbol(from line: String, prefix: String, kind: DocumentSymbolKind, at location: Int, fullLine: String) -> DocumentSymbol? {
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
