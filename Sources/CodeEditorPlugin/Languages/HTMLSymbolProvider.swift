import CodeEditorTextModel
import Foundation

/// HTML symbol provider for detecting HTML elements and structure
struct HTMLSymbolProvider: LineBasedSymbolProvider {
    /// Pre-compiled regex for the only two attributes this provider ever
    /// extracts — `id` and `class`. Previously the pattern was rebuilt and
    /// the regex re-compiled on every call to `extractAttribute(_:from:)`,
    /// once per HTML line in the document. `NSRegularExpression` is
    /// documented as thread-safe and the patterns are static, so a
    /// `static let` is correct here.
    private static let idAttributeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "id\\s*=\\s*[\"']([^\"']*)[\"']",
        options: .caseInsensitive
    )
    private static let classAttributeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "class\\s*=\\s*[\"']([^\"']*)[\"']",
        options: .caseInsensitive
    )

    func detectSymbol(in line: String, at location: Int, lineIndex _: Int, fullLine: String) -> DocumentSymbol? {
        // Skip comments and doctype
        if line.hasPrefix("<!--") || line.hasPrefix("<!DOCTYPE") || line.hasPrefix("<?") {
            return nil
        }

        // Detect opening tags
        if line.hasPrefix("<") && !line.hasPrefix("</") {
            return extractHTMLElement(from: line, at: location, fullLine: fullLine)
        }

        return nil
    }

    private func extractHTMLElement(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Extract tag name
        guard let startIndex = line.firstIndex(of: "<") else { return nil }
        let afterStart = line[line.index(after: startIndex)...]

        // Find the tag name (until space, > or /)
        let tagName = String(afterStart.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })

        guard !tagName.isEmpty else { return nil }

        // Determine symbol kind based on tag type
        let kind = symbolKind(for: tagName)

        // Extract id or class for better identification
        var detail = tagName
        if let idMatch = extractAttribute(matching: Self.idAttributeRegex, from: line) {
            detail += "#\(idMatch)"
        } else if let classMatch = extractAttribute(matching: Self.classAttributeRegex, from: line) {
            detail += ".\(classMatch.components(separatedBy: " ").first ?? classMatch)"
        }

        return DocumentSymbol(
            name: detail,
            kind: kind,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: line.trimmingCharacters(in: .whitespaces)
        )
    }

    private func symbolKind(for tagName: String) -> DocumentSymbolKind {
        switch tagName.lowercased() {
        case "html", "head", "body":
            return .module

        case "div", "section", "article", "header", "footer", "main", "aside", "nav":
            return .namespace

        case "h1", "h2", "h3", "h4", "h5", "h6":
            return .field

        case "form", "table", "ul", "ol", "dl":
            return .object

        case "script":
            return .function

        case "style", "link":
            return .property

        default:
            return .key
        }
    }

    private func extractAttribute(matching regex: NSRegularExpression?, from line: String) -> String? {
        guard let regex else { return nil }

        let range = NSRange(location: 0, length: TextRangeUtilities.utf16Length(of: line))
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges > 1 else {
            return nil
        }

        let valueRange = match.range(at: 1)
        guard let swiftRange = Range(valueRange, in: line) else { return nil }
        return String(line[swiftRange])
    }
}
