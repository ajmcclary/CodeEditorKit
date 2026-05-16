import Foundation

/// Markdown symbol provider for detecting headers and section structure
struct MarkdownSymbolProvider: LineBasedSymbolProvider {
    func detectSymbol(in line: String, at location: Int, lineIndex _: Int, fullLine: String) -> DocumentSymbol? {
        // Header detection
        if line.hasPrefix("#") {
            let level = line.prefix { $0 == "#" }.count
            if level >= 1 && level <= 6 {
                let headerText = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)

                return DocumentSymbol(
                    name: headerText,
                    kind: level == 1 ? .module : .namespace,
                    range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                    detail: "Level \(level) heading"
                )
            }
        }

        return nil
    }
}
