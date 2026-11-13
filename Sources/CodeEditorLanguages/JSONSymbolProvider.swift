import CodeEditorTextModel
import Foundation

/// JSON symbol provider for detecting JSON structure and keys
package struct JSONSymbolProvider: DocumentSymbolProvider {
    package init() {}

    package func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []

        // Try to parse JSON structure
        guard let data = text.data(using: .utf8) else { return [] }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            let keyLocations = Self.firstKeyLocations(in: text)
            symbols = extractSymbols(from: jsonObject, keyLocations: keyLocations, path: [])
        } catch {
            // Fallback to line-by-line parsing for malformed JSON
            symbols = parseLineByLine(text: text)
        }

        return symbols
    }

    /// Symbols for every key, in pre-order (a key, then the keys inside its
    /// value). Walks the parsed value with an explicit stack: recursing per
    /// nesting level let a deeply nested document set the stack depth.
    private func extractSymbols(from object: Any, keyLocations: [String: Int], path _: [String]) -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        // Each frame is the remaining children of one container, in order.
        var frames: [IndexingIterator<[(key: String?, value: Any)]>] = [Self.children(of: object).makeIterator()]

        while !frames.isEmpty {
            guard let (key, value) = frames[frames.count - 1].next() else {
                frames.removeLast()
                continue
            }
            if let key {
                let kind = symbolKind(for: value)
                let detail = symbolDetail(for: value)
                symbols.append(DocumentSymbol(
                    name: key,
                    kind: kind,
                    range: NSRange(
                        location: keyLocations[key] ?? 0,
                        length: TextRangeUtilities.utf16Length(of: key) + TextRangeUtilities.utf16Length(of: detail) + 4
                    ), // approximate
                    detail: detail
                ))
                guard kind == .object || kind == .array else { continue }
            } else if !(value is [String: Any]) {
                // Array elements contribute only through dictionaries.
                continue
            }
            frames.append(Self.children(of: value).makeIterator())
        }

        return symbols
    }

    /// A dictionary's entries (keyed) or an array's elements (unkeyed).
    private static func children(of object: Any) -> [(key: String?, value: Any)] {
        if let dictionary = object as? [String: Any] {
            return dictionary.map { (key: $0.key, value: $0.value) }
        }
        if let array = object as? [Any] {
            return array.map { (key: nil, value: $0) }
        }
        return []
    }

    private func parseLineByLine(text: String) -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectJSONSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }

            currentLocation += TextRangeUtilities.utf16Length(of: line) + 1
        }

        return symbols
    }

    private func detectJSONSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Detect JSON keys (quoted strings followed by colon)
        if let colonIndex = trimmed.firstIndex(of: ":") {
            let beforeColon = String(trimmed.prefix(upTo: colonIndex)).trimmingCharacters(in: .whitespaces)

            // Extract quoted key
            if beforeColon.hasPrefix("\"") && beforeColon.hasSuffix("\"") && beforeColon.count > 2 {
                let key = String(beforeColon.dropFirst().dropLast())
                let afterColon = String(trimmed.suffix(from: trimmed.index(after: colonIndex))).trimmingCharacters(in: .whitespaces)

                let kind = inferKind(from: afterColon)
                let detail = getValuePreview(from: afterColon)

                return DocumentSymbol(
                    name: key,
                    kind: kind,
                    range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: line)),
                    detail: detail
                )
            }
        }

        return nil
    }

    private func symbolKind(for value: Any) -> DocumentSymbolKind {
        switch value {
        case is [String: Any]:
            return .object

        case is [Any]:
            return .array

        case is String:
            return .string

        case is Int, is Double, is Float:
            return .number

        case is Bool:
            return .boolean

        case is NSNull:
            return .null

        default:
            return .key
        }
    }

    private func symbolDetail(for value: Any) -> String {
        switch value {
        case let dict as [String: Any]:
            return "object {\(dict.keys.count) keys}"

        case let array as [Any]:
            return "array [\(array.count) items]"

        case let string as String:
            let preview = string.prefix(30)
            return preview.count < string.count ? "\"\(preview)...\"" : "\"\(string)\""

        case let int as Int:
            return "\(int)"

        case let double as Double:
            return "\(double)"

        case let float as Float:
            return "\(float)"

        case let bool as Bool:
            return "\(bool)"

        case is NSNull:
            return "null"

        default:
            return "unknown"
        }
    }

    private func inferKind(from valueText: String) -> DocumentSymbolKind {
        let trimmed = valueText.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("{") {
            return .object
        } else if trimmed.hasPrefix("[") {
            return .array
        } else if trimmed.hasPrefix("\"") {
            return .string
        } else if trimmed == "true" || trimmed == "false" {
            return .boolean
        } else if trimmed == "null" {
            return .null
        } else if Double(trimmed) != nil {
            return .number
        } else {
            return .key
        }
    }

    private func getValuePreview(from valueText: String) -> String {
        let trimmed = valueText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")

        if trimmed.count > 50 {
            return String(trimmed.prefix(50)) + "..."
        }
        return trimmed
    }

    /// Matches a quoted string immediately followed by `:` (a key).
    private static let keyRegex = try? NSRegularExpression(pattern: #""((?:[^"\\\n]|\\.)*)":"#)

    /// UTF-16 location of the first `"key":` for every key text in `text`,
    /// built in one pass. (Searching the document once per key was
    /// quadratic, and returned a `Character` distance, not a UTF-16 offset.)
    private static func firstKeyLocations(in text: String) -> [String: Int] {
        guard let keyRegex else { return [:] }
        var locations: [String: Int] = [:]
        for match in keyRegex.matches(in: text, range: TextRangeUtilities.fullRange(in: text)) {
            guard let key = TextRangeUtilities.substring(inUTF16Range: match.range(at: 1), from: text) else { continue }
            if locations[key] == nil {
                locations[key] = match.range.location
            }
        }
        return locations
    }
}
