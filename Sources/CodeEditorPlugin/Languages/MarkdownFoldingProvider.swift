import CodeEditorTextModel
import Foundation

// MARK: - Markdown Folding Provider

/// Markdown section folding provider
internal struct MarkdownFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        let lines = text.components(separatedBy: .newlines)

        var headerStack: [(Int, Int, String)] = [] // (lineIndex, level, title)

        for (index, line) in lines.enumerated() {
            if let headerLevel = markdownHeaderLevel(line) {
                // Close sections at same or higher level
                while let last = headerStack.last, last.1 >= headerLevel {
                    let (startLine, _, title) = headerStack.removeLast()

                    let startLocation = TextRangeUtilities.locationForLine(startLine, in: lines)
                    let endLocation = TextRangeUtilities.locationForLine(index - 1, in: lines) + lines[index - 1].count

                    regions.append(FoldableRegion(
                        range: NSRange(location: startLocation, length: endLocation - startLocation),
                        title: title,
                        type: .region
                    ))
                }

                headerStack.append((index, headerLevel, line))
            }
        }

        // Close remaining sections
        while let (startLine, _, title) = headerStack.popLast() {
            let startLocation = TextRangeUtilities.locationForLine(startLine, in: lines)
            let endLocation = text.count

            regions.append(FoldableRegion(
                range: NSRange(location: startLocation, length: endLocation - startLocation),
                title: title,
                type: .region
            ))
        }

        return regions
    }

    private func markdownHeaderLevel(_ line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        let level = trimmed.prefix { $0 == "#" }.count
        return level <= 6 ? level : nil
    }
}
