import Foundation

/// Markdown symbol provider for detecting headers and section structure
struct MarkdownSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectMarkdownSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }

            currentLocation += TextRangeUtilities.utf16Length(of: line) + 1
        }

        return symbols
    }

    private func detectMarkdownSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Header detection
        if trimmed.hasPrefix("#") {
            let level = trimmed.prefix { $0 == "#" }.count
            if level >= 1 && level <= 6 {
                let headerText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)

                return DocumentSymbol(
                    name: headerText,
                    kind: level == 1 ? .module : .namespace,
                    range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: line)),
                    detail: "Level \(level) heading"
                )
            }
        }

        return nil
    }
}
