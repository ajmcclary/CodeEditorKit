import Foundation

/// JavaScript/TypeScript symbol provider for detecting functions, classes, and variables
struct JavaScriptSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let symbol = detectJavaScriptSymbol(in: trimmed, at: currentLocation, line: lineIndex, fullLine: line) {
                symbols.append(symbol)
            }

            currentLocation += line.count + 1
        }

        return symbols
    }

    private func detectJavaScriptSymbol(in line: String, at location: Int, line _: Int, fullLine: String) -> DocumentSymbol? {
        // Function detection
        if line.hasPrefix("function ") || line.contains("= function") || line.contains("=> {") {
            return extractJSFunction(from: line, at: location, fullLine: fullLine)
        }

        // Class detection
        if line.hasPrefix("class ") {
            return extractSymbol(from: line, prefix: "class", kind: .class, at: location, fullLine: fullLine)
        }

        // Const/let/var detection
        if line.hasPrefix("const ") || line.hasPrefix("let ") || line.hasPrefix("var ") {
            let prefix = line.hasPrefix("const ") ? "const" : (line.hasPrefix("let ") ? "let" : "var")
            let kind: DocumentSymbolKind = line.hasPrefix("const ") ? .constant : .variable
            return extractSymbol(from: line, prefix: prefix, kind: kind, at: location, fullLine: fullLine)
        }

        return nil
    }

    private func extractJSFunction(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Extract function name
        var name = ""

        if line.hasPrefix("function ") {
            let afterFunction = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            name = String(afterFunction.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "$" })
        } else if line.contains("= function") {
            // Extract name before = function
            if let eqIndex = line.firstIndex(of: "=") {
                let beforeEq = String(line.prefix(upTo: eqIndex)).trimmingCharacters(in: .whitespaces)
                name = beforeEq.components(separatedBy: .whitespaces).last ?? ""
            }
        } else if line.contains("=>") {
            // Arrow function
            if let arrowIndex = line.range(of: "=>") {
                let beforeArrow = String(line.prefix(upTo: arrowIndex.lowerBound)).trimmingCharacters(in: .whitespaces)
                name = beforeArrow.components(separatedBy: .whitespaces).last ?? ""
            }
        }

        guard !name.isEmpty else { return nil }

        return DocumentSymbol(
            name: name,
            kind: .function,
            range: NSRange(location: location, length: fullLine.count),
            detail: line
        )
    }

    private func extractSymbol(from line: String, prefix: String, kind: DocumentSymbolKind, at location: Int, fullLine: String) -> DocumentSymbol? {
        let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let name = afterPrefix.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "$" }

        guard !name.isEmpty else { return nil }

        return DocumentSymbol(
            name: String(name),
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            detail: line
        )
    }
}
