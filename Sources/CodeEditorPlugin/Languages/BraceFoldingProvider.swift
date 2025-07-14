import Foundation

// MARK: - Brace Folding Provider

/// Brace-based folding provider for C-style languages
internal struct BraceFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        // Simple brace matching
        var braceStack: [(Character, Int)] = []
        
        for index in 0..<text.utf16.count {
            guard let charIndex = text.utf16.index(text.utf16.startIndex, offsetBy: index, limitedBy: text.utf16.endIndex) else { continue }
            let char = text.utf16[charIndex]
            // Handle surrogate pairs safely
            guard let scalar = UnicodeScalar(char),
                  !UTF16.isLeadSurrogate(char) && !UTF16.isTrailSurrogate(char) else {
                continue
            }
            let unicodeChar = Character(scalar)
            
            switch unicodeChar {
            case "{":
                braceStack.append(("{", index))
                
            case "}":
                if let (openBrace, openIndex) = braceStack.popLast(), openBrace == "{" {
                    let range = NSRange(location: openIndex, length: index - openIndex + 1)
                    
                    // Determine type based on context
                    let type = determineFoldingType(at: openIndex, in: text)
                    let title = extractTitle(at: openIndex, in: text, type: type)
                    
                    regions.append(FoldableRegion(
                        range: range,
                        title: title,
                        type: type
                    ))
                }
                
            default:
                break
            }
        }
        
        return regions
    }
    
    private func determineFoldingType(at location: Int, in text: String) -> FoldingType {
        // Simple heuristic - check for keywords before the brace
        let prefix = String(text.prefix(location))
        
        if prefix.hasSuffix("class ") || prefix.hasSuffix("struct ") {
            return .class
        } else if prefix.hasSuffix("func ") || prefix.hasSuffix("function ") {
            return .function
        } else if prefix.contains("//") || prefix.contains("/*") {
            return .comment
        } else {
            return .block
        }
    }
    
    private func extractTitle(at location: Int, in text: String, type _: FoldingType) -> String {
        let lineRange = RangeUtilities.lineRange(containing: location, in: text)
        let lineStart = lineRange.location
        
        guard let startIndex = text.index(text.startIndex, offsetBy: lineStart, limitedBy: text.endIndex),
              let endIndex = text.index(text.startIndex, offsetBy: location, limitedBy: text.endIndex) else {
            return ""
        }
        
        let linePrefix = String(text[startIndex..<endIndex])
        return linePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
