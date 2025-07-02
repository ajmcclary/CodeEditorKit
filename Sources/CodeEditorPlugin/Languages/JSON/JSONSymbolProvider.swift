import Foundation

/// JSON symbol provider for detecting JSON structure and keys
struct JSONSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        
        // Try to parse JSON structure
        guard let data = text.data(using: .utf8) else { return [] }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            symbols = extractSymbols(from: jsonObject, text: text, path: [])
        } catch {
            // Fallback to line-by-line parsing for malformed JSON
            symbols = parseLineByLine(text: text)
        }
        
        return symbols
    }
    
    private func extractSymbols(from object: Any, text: String, path: [String]) -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                let currentPath = path + [key]
                let location = findKeyLocation(key: key, in: text, path: currentPath)
                
                let kind = symbolKind(for: value)
                let detail = symbolDetail(for: value)
                
                let symbol = DocumentSymbol(
                    name: key,
                    kind: kind,
                    range: NSRange(location: location, length: key.count + detail.count + 4), // approximate
                    detail: detail
                )
                
                symbols.append(symbol)
                
                // Recursively process nested objects
                if kind == .object || kind == .array {
                    symbols.append(contentsOf: extractSymbols(from: value, text: text, path: currentPath))
                }
            }
        } else if let array = object as? [Any] {
            for (index, item) in array.enumerated() {
                if let dict = item as? [String: Any] {
                    symbols.append(contentsOf: extractSymbols(from: dict, text: text, path: path + ["[\(index)]"]))
                }
            }
        }
        
        return symbols
    }
    
    private func parseLineByLine(text: String) -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectJSONSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }
            
            currentLocation += line.count + 1
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
                    range: NSRange(location: location, length: line.count),
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
    
    private func findKeyLocation(key: String, in text: String, path _: [String]) -> Int {
        // Simple implementation - in a real scenario, you'd want more sophisticated location finding
        if let range = text.range(of: "\"\(key)\":") {
            return text.distance(from: text.startIndex, to: range.lowerBound)
        }
        return 0
    }
}
