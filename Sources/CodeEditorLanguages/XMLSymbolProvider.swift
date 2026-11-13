import CodeEditorTextModel
import Foundation

/// XML symbol provider for detecting XML elements and structure
package struct XMLSymbolProvider: StatefulLineBasedSymbolProvider {
    package typealias State = [String] // element stack

    package init() {}

    package func makeState() -> State { [] }

    package func detectSymbols(
        in line: String,
        at location: Int,
        lineIndex _: Int,
        fullLine: String,
        state: inout State
    ) -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []

        // Skip comments and declarations
        if line.hasPrefix("<!--") || line.hasPrefix("<?") || line.hasPrefix("<!DOCTYPE") {
            return symbols
        }

        // Process all XML tags in the line. The scan walks indices of `line`
        // without copying the remainder, and offsets are UTF-16 offsets of
        // the tag within `fullLine` (`line` is `fullLine` minus its leading
        // whitespace).
        let leadingWhitespaceLength = TextRangeUtilities.utf16Length(
            of: String(fullLine.prefix { $0.unicodeScalars.allSatisfy(CharacterSet.whitespaces.contains) })
        )
        var searchStart = line.startIndex

        while let tagRange = findNextXMLTag(in: line, from: searchStart) {
            let tag = String(line[tagRange])
            let tagOffset = line.utf16.distance(from: line.startIndex, to: tagRange.lowerBound)

            if let symbol = processXMLTag(
                tag,
                at: location + leadingWhitespaceLength + tagOffset,
                fullLine: fullLine,
                elementStack: &state
            ) {
                symbols.append(symbol)
            }

            searchStart = tagRange.upperBound
        }

        return symbols
    }

    private func findNextXMLTag(in text: String, from start: String.Index) -> Range<String.Index>? {
        guard let startIndex = text[start...].firstIndex(of: "<"),
              let endIndex = text[text.index(after: startIndex)...].firstIndex(of: ">") else {
            return nil
        }

        return startIndex..<text.index(after: endIndex)
    }

    private func processXMLTag(_ tag: String, at location: Int, fullLine: String, elementStack: inout [String]) -> DocumentSymbol? {
        let cleanTag = tag.trimmingCharacters(in: .whitespaces)

        // Self-closing tag
        if cleanTag.hasSuffix("/>") {
            return extractXMLElement(from: cleanTag, at: location, fullLine: fullLine, isSelfClosing: true)
        }

        // Closing tag
        if cleanTag.hasPrefix("</") {
            let tagName = extractTagName(from: cleanTag)
            if !tagName.isEmpty && elementStack.last == tagName {
                elementStack.removeLast()
            }
            return nil // Don't create symbols for closing tags
        }

        // Opening tag
        if cleanTag.hasPrefix("<") && !cleanTag.hasPrefix("<!") && !cleanTag.hasPrefix("<?") {
            let symbol = extractXMLElement(from: cleanTag, at: location, fullLine: fullLine, isSelfClosing: false)

            if let symbol {
                elementStack.append(symbol.name.components(separatedBy: " ").first ?? symbol.name)
            }

            return symbol
        }

        return nil
    }

    private func extractXMLElement(from tag: String, at location: Int, fullLine: String, isSelfClosing: Bool) -> DocumentSymbol? {
        let tagName = extractTagName(from: tag)
        guard !tagName.isEmpty else { return nil }

        let kind = xmlElementKind(for: tagName)

        // Extract attributes for better identification
        var detail = tagName
        if let attributes = extractKeyAttributes(from: tag) {
            detail += " \(attributes)"
        }

        if isSelfClosing {
            detail += " (self-closing)"
        }

        return DocumentSymbol(
            name: detail,
            kind: kind,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: tag
        )
    }

    private func extractTagName(from tag: String) -> String {
        var cleanTag = tag

        // Remove < and /> or >
        if cleanTag.hasPrefix("</") {
            cleanTag = String(cleanTag.dropFirst(2))
        } else if cleanTag.hasPrefix("<") {
            cleanTag = String(cleanTag.dropFirst())
        }

        if cleanTag.hasSuffix("/>") {
            cleanTag = String(cleanTag.dropLast(2))
        } else if cleanTag.hasSuffix(">") {
            cleanTag = String(cleanTag.dropLast())
        }

        // Extract just the tag name (before any attributes)
        return cleanTag.prefix { !$0.isWhitespace }.trimmingCharacters(in: .whitespaces)
    }

    private func xmlElementKind(for tagName: String) -> DocumentSymbolKind {
        switch tagName.lowercased() {
        case "root", "document", "xml":
            return .module

        case "config", "configuration", "settings", "properties":
            return .namespace

        case "item", "entry", "record", "row":
            return .object

        case "list", "array", "collection":
            return .array

        case "property", "attribute", "param", "parameter":
            return .property

        case "value", "data", "content", "text":
            return .string

        case "id", "key", "name":
            return .constant

        default:
            return .key
        }
    }

    private func extractKeyAttributes(from tag: String) -> String? {
        var attributes: [String] = []

        // Look for id attribute
        if let idValue = extractAttributeValue("id", from: tag) {
            attributes.append("id=\"\(idValue)\"")
        }

        // Look for name attribute
        if let nameValue = extractAttributeValue("name", from: tag) {
            attributes.append("name=\"\(nameValue)\"")
        }

        // Look for type attribute
        if let typeValue = extractAttributeValue("type", from: tag) {
            attributes.append("type=\"\(typeValue)\"")
        }

        return attributes.isEmpty ? nil : attributes.joined(separator: " ")
    }

    private func extractAttributeValue(_ attributeName: String, from tag: String) -> String? {
        let pattern = "\(attributeName)\\s*=\\s*[\"']([^\"']*)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(location: 0, length: TextRangeUtilities.utf16Length(of: tag))
        guard let match = regex.firstMatch(in: tag, options: [], range: range),
              match.numberOfRanges > 1 else {
            return nil
        }

        let valueRange = match.range(at: 1)
        guard let swiftRange = Range(valueRange, in: tag) else { return nil }
        return String(tag[swiftRange])
    }
}
