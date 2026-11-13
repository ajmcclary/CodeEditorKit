import CodeEditorTextModel
import Foundation

// MARK: - Indentation Folding Provider

/// Indentation-based folding provider for languages like Python and YAML
package struct IndentationFoldingProvider: CodeFoldingProvider {
    package init() {}

    package func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        let lines = text.components(separatedBy: .newlines)
        // Looking each line start up by summing the lines before it made
        // detection quadratic; compute them once.
        let lineLocations = utf16LineStartLocations(of: lines)

        var indentStack: [(Int, Int, String)] = [] // (lineIndex, indentLevel, title)

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }

            let indentLevel = line.prefix { $0 == " " || $0 == "\t" }.count

            // Close regions with higher indent level
            while let last = indentStack.last, last.1 >= indentLevel {
                let (startLine, _, title) = indentStack.removeLast()

                if index - startLine >= 2 { // Minimum lines for folding
                    let startLocation = lineLocations[startLine]
                    let endLocation = lineLocations[index - 1] + TextRangeUtilities.utf16Length(of: lines[index - 1])

                    regions.append(FoldableRegion(
                        range: NSRange(location: startLocation, length: endLocation - startLocation),
                        title: title,
                        type: .block
                    ))
                }
            }

            // Start new region if this line ends with ":"
            if trimmedLine.hasSuffix(":") {
                indentStack.append((index, indentLevel, trimmedLine))
            }
        }

        return regions
    }
}
