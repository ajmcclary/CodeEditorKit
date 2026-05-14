import Foundation

/// CSS symbol provider for detecting CSS rules, selectors, and at-rules
struct CSSSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectCSSSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }

            currentLocation += TextRangeUtilities.utf16Length(of: line) + 1
        }

        return symbols
    }

    private func detectCSSSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip comments and empty lines
        if trimmed.hasPrefix("/*") || trimmed.isEmpty {
            return nil
        }

        // Detect at-rules
        if trimmed.hasPrefix("@") {
            return extractAtRule(from: trimmed, at: location, fullLine: line)
        }

        // Detect CSS selectors (lines ending with { or containing {)
        if trimmed.hasSuffix("{") || (trimmed.contains("{") && !trimmed.contains("}")) {
            return extractCSSSelector(from: trimmed, at: location, fullLine: line)
        }

        return nil
    }

    private func extractAtRule(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Extract at-rule name
        let afterAt = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        let ruleName = afterAt.prefix { !$0.isWhitespace && $0 != "{" && $0 != "(" }

        guard !ruleName.isEmpty else { return nil }

        let kind = atRuleKind(for: String(ruleName))

        // Extract additional info (like media query conditions)
        var detail = "@\(ruleName)"
        if ruleName == "media" || ruleName == "supports" {
            if let conditionStart = afterAt.firstIndex(where: { !$0.isLetter }),
               let openBrace = line.firstIndex(of: "{") {
                let condition = String(afterAt[conditionStart..<afterAt.index(openBrace, offsetBy: -afterAt.distance(from: line.startIndex, to: openBrace))])
                    .trimmingCharacters(in: .whitespaces)
                detail += " \(condition)"
            }
        }

        return DocumentSymbol(
            name: detail,
            kind: kind,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: line.trimmingCharacters(in: .whitespaces)
        )
    }

    private func extractCSSSelector(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Remove the opening brace and clean up
        let selector = line.replacingOccurrences(of: "{", with: "").trimmingCharacters(in: .whitespaces)

        guard !selector.isEmpty else { return nil }

        let kind = selectorKind(for: selector)

        return DocumentSymbol(
            name: selector,
            kind: kind,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: line.trimmingCharacters(in: .whitespaces)
        )
    }

    private func atRuleKind(for ruleName: String) -> DocumentSymbolKind {
        switch ruleName.lowercased() {
        case "media", "supports", "document":
            return .namespace

        case "import", "charset":
            return .module

        case "keyframes", "counter-style":
            return .function

        case "font-face", "page":
            return .interface

        default:
            return .property
        }
    }

    private func selectorKind(for selector: String) -> DocumentSymbolKind {
        if selector.contains("#") {
            return .constant // ID selector
        } else if selector.contains(".") {
            return .property // Class selector
        } else if selector.contains("::") || selector.contains(":") {
            return .function // Pseudo-element or pseudo-class
        } else if selector.contains("[") && selector.contains("]") {
            return .field // Attribute selector
        } else {
            return .key // Element selector
        }
    }
}
