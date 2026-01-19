import Foundation

/// Swift symbol provider for detecting Swift classes, structs, enums, functions, and properties
struct SwiftSymbolProvider: LineBasedSymbolProvider {
    func detectSymbol(in line: String, at location: Int, lineIndex _: Int, fullLine: String) -> DocumentSymbol? {
        // Class detection (handles 'final class' as well)
        if line.hasPrefix("class ") || line.hasPrefix("final class ") {
            let prefix = line.hasPrefix("final class ") ? "final class " : "class "
            return extractSymbolWithSelectionRange(from: line, prefix: prefix, kind: .class, at: location, fullLine: fullLine)
        }

        // Struct detection
        if line.hasPrefix("struct ") {
            return extractSymbolWithSelectionRange(from: line, prefix: "struct ", kind: .struct, at: location, fullLine: fullLine)
        }

        // Enum detection
        if line.hasPrefix("enum ") {
            return extractSymbolWithSelectionRange(from: line, prefix: "enum ", kind: .enum, at: location, fullLine: fullLine)
        }

        // Protocol detection
        if line.hasPrefix("protocol ") {
            return extractSymbolWithSelectionRange(from: line, prefix: "protocol ", kind: .interface, at: location, fullLine: fullLine)
        }

        // Actor detection
        if line.hasPrefix("actor ") {
            return extractSymbolWithSelectionRange(from: line, prefix: "actor ", kind: .class, at: location, fullLine: fullLine)
        }

        // Function detection
        if line.hasPrefix("func ") {
            return extractSymbolWithSelectionRange(from: line, prefix: "func ", kind: .function, at: location, fullLine: fullLine)
        }

        // Property detection
        if line.hasPrefix("var ") {
            return extractSymbolWithSelectionRange(from: line, prefix: "var ", kind: .variable, at: location, fullLine: fullLine)
        }

        if line.hasPrefix("let ") {
            return extractSymbolWithSelectionRange(from: line, prefix: "let ", kind: .constant, at: location, fullLine: fullLine)
        }

        return nil
    }
}
