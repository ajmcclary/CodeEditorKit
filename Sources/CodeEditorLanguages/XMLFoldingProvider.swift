import CodeEditorTextModel
import Foundation

// MARK: - XML Folding Provider

/// XML/HTML tag folding provider
package struct XMLFoldingProvider: CodeFoldingProvider {
    /// Opening tags (`<name …>`) and closing tags (`</name>`) in one pass.
    /// Group 1 is a closing tag's name, group 2 an opening tag's name.
    private static let tagRegex = try? NSRegularExpression(pattern: "</([^>]+)>|<([^/>\\s]+)[^>]*>")

    package init() {}

    package func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        guard let tagRegex = Self.tagRegex else { return [] }

        // All offsets are UTF-16 offsets into `text`, and names are taken by
        // UTF-16 range, so CRLF and non-BMP text stay aligned.
        let matches = tagRegex.matches(in: text, range: TextRangeUtilities.fullRange(in: text))
        func substring(_ range: NSRange) -> String {
            TextRangeUtilities.substring(inUTF16Range: range, from: text) ?? ""
        }

        var regions: [FoldableRegion] = []
        var openStack: [(name: String, range: NSRange)] = []

        for match in matches {
            let closeNameRange = match.range(at: 1)
            if closeNameRange.location != NSNotFound {
                let closeName = substring(closeNameRange).trimmingCharacters(in: .whitespaces)
                // Unclosed elements above the match (HTML void elements,
                // malformed markup) are discarded with it.
                guard let openIndex = openStack.lastIndex(where: { $0.name == closeName }) else { continue }
                let open = openStack[openIndex]
                openStack.removeSubrange(openIndex...)
                regions.append(FoldableRegion(
                    range: NSRange(
                        location: open.range.location,
                        length: NSMaxRange(match.range) - open.range.location
                    ),
                    title: "<\(open.name)>",
                    type: .block
                ))
                continue
            }

            let openNameRange = match.range(at: 2)
            guard openNameRange.location != NSNotFound else { continue }
            let tagName = substring(openNameRange)
            // Declarations, comments, processing instructions and
            // self-closing tags never get a closing tag.
            if tagName.hasPrefix("!") || tagName.hasPrefix("?") { continue }
            if substring(match.range).hasSuffix("/>") { continue }
            openStack.append((name: tagName, range: match.range))
        }

        // Report regions in document order of their opening tags.
        return regions.sorted { $0.range.location < $1.range.location }
    }
}
