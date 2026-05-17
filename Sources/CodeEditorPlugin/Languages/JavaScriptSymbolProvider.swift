import CodeEditorTextModel
import Foundation

/// JavaScript/TypeScript symbol provider for detecting functions, classes, and variables
package struct JavaScriptSymbolProvider: LineBasedSymbolProvider {
    package init() {}

    package func detectSymbol(in line: String, at location: Int, lineIndex _: Int, fullLine: String) -> DocumentSymbol? {
        // Function detection
        if line.hasPrefix("function ") || line.contains("= function") || line.contains("=> {") {
            return extractJSFunction(from: line, at: location, fullLine: fullLine)
        }

        // Class detection
        if line.hasPrefix("class ") {
            return extractSymbol(from: line, prefix: "class ", kind: .class, at: location, fullLine: fullLine, validChars: "_$")
        }

        // Const detection
        if line.hasPrefix("const ") {
            return extractSymbol(from: line, prefix: "const ", kind: .constant, at: location, fullLine: fullLine, validChars: "_$")
        }

        // Let detection
        if line.hasPrefix("let ") {
            return extractSymbol(from: line, prefix: "let ", kind: .variable, at: location, fullLine: fullLine, validChars: "_$")
        }

        // Var detection
        if line.hasPrefix("var ") {
            return extractSymbol(from: line, prefix: "var ", kind: .variable, at: location, fullLine: fullLine, validChars: "_$")
        }

        return nil
    }

    private func extractJSFunction(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Extract function name
        var name = ""

        if line.hasPrefix("function ") {
            let afterFunction = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            name = String(afterFunction.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "$" })
        } else if line.contains("= function") {
            // Extract name before = function
            if let eqIndex = line.firstIndex(of: "=") {
                let beforeEq = String(line.prefix(upTo: eqIndex)).trimmingCharacters(in: .whitespaces)
                name = beforeEq.components(separatedBy: .whitespaces).last ?? ""
            }
        } else if line.contains("=>") {
            // Arrow function
            if let arrowIndex = line.range(of: "=>") {
                let beforeArrow = String(line.prefix(upTo: arrowIndex.lowerBound)).trimmingCharacters(in: .whitespaces)
                name = beforeArrow.components(separatedBy: .whitespaces).last ?? ""
            }
        }

        guard !name.isEmpty else { return nil }

        return DocumentSymbol(
            name: name,
            kind: .function,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: line
        )
    }
}
