import Foundation

// MARK: - Indentation Folding Provider

/// Indentation-based folding provider for languages like Python and YAML
internal struct IndentationFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        let lines = text.components(separatedBy: .newlines)
        
        var indentStack: [(Int, Int, String)] = [] // (lineIndex, indentLevel, title)
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }
            
            let indentLevel = line.prefix { $0 == " " || $0 == "\t" }.count
            
            // Close regions with higher indent level
            while let last = indentStack.last, last.1 >= indentLevel {
                let (startLine, _, title) = indentStack.removeLast()
                
                if index - startLine >= 2 { // Minimum lines for folding
                    let startLocation = locationForLine(startLine, in: lines)
                    let endLocation = locationForLine(index - 1, in: lines) + lines[index - 1].count
                    
                    regions.append(FoldableRegion(
                        range: NSRange(location: startLocation, length: endLocation - startLocation),
                        title: title,
                        type: .block
                    ))
                }
            }
            
            // Start new region if this line ends with ":"
            if trimmedLine.hasSuffix(":") {
                indentStack.append((index, indentLevel, trimmedLine))
            }
        }
        
        return regions
    }
    
    private func locationForLine(_ lineIndex: Int, in lines: [String]) -> Int {
        var location = 0
        for index in 0..<lineIndex {
            location += lines[index].count + 1 // +1 for newline
        }
        return location
    }
}
