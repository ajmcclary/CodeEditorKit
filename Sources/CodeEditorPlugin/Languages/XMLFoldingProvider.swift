import Foundation

// MARK: - XML Folding Provider

/// XML/HTML tag folding provider
internal struct XMLFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []

        // Simple XML tag matching
        let tagPattern = "<([^/>\\s]+)[^>]*>"
        let closeTagPattern = "</([^>]+)>"

        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern),
              let closeTagRegex = try? NSRegularExpression(pattern: closeTagPattern) else {
            return regions
        }

        let range = NSRange(location: 0, length: text.utf16.count)

        let openTags = tagRegex.matches(in: text, range: range)
        let closeTags = closeTagRegex.matches(in: text, range: range)

        // Match opening and closing tags
        for openMatch in openTags {
            let tagNameRange = openMatch.range(at: 1)
            guard let startIndex = text.index(text.startIndex, offsetBy: tagNameRange.location, limitedBy: text.endIndex),
                  let endIndex = text.index(startIndex, offsetBy: tagNameRange.length, limitedBy: text.endIndex) else { continue }
            let tagName = String(text[startIndex..<endIndex])

            // Find corresponding close tag
            if let closeMatch = closeTags.first(where: { closeMatch in
                let closeNameRange = closeMatch.range(at: 1)
                guard let closeStartIndex = text.index(text.startIndex, offsetBy: closeNameRange.location, limitedBy: text.endIndex),
                      let closeEndIndex = text.index(closeStartIndex, offsetBy: closeNameRange.length, limitedBy: text.endIndex) else { return false }
                let closeName = String(text[closeStartIndex..<closeEndIndex])
                return closeName == tagName && closeMatch.range.location > openMatch.range.location
            }) {
                let foldRange = NSRange(
                    location: openMatch.range.location,
                    length: NSMaxRange(closeMatch.range) - openMatch.range.location
                )

                regions.append(FoldableRegion(
                    range: foldRange,
                    title: "<\(tagName)>",
                    type: .block
                ))
            }
        }

        return regions
    }
}
