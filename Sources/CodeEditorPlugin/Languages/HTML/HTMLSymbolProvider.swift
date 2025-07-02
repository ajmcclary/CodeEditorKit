import Foundation

/// HTML symbol provider for detecting HTML elements and structure
struct HTMLSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectHTMLSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }
            
            currentLocation += line.count + 1
        }
        
        return symbols
    }
    
    private func detectHTMLSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Skip comments and doctype
        if trimmed.hasPrefix("<!--") || trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<?") {
            return nil
        }
        
        // Detect opening tags
        if trimmed.hasPrefix("<") && !trimmed.hasPrefix("</") {
            return extractHTMLElement(from: trimmed, at: location, fullLine: line)
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
        if let idMatch = extractAttribute("id", from: line) {
            detail += "#\(idMatch)"
        } else if let classMatch = extractAttribute("class", from: line) {
            detail += ".\(classMatch.components(separatedBy: " ").first ?? classMatch)"
        }
        
        return DocumentSymbol(
            name: detail,
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
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
    
    private func extractAttribute(_ attributeName: String, from line: String) -> String? {
        let pattern = "\(attributeName)\\s*=\\s*[\"']([^\"']*)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: line.count)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges > 1 else {
            return nil
        }
        
        let valueRange = match.range(at: 1)
        guard let swiftRange = Range(valueRange, in: line) else { return nil }
        return String(line[swiftRange])
    }
}
