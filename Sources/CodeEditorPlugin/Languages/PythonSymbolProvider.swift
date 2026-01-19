import Foundation

/// Python symbol provider for detecting Python classes, functions, and methods
struct PythonSymbolProvider: LineBasedSymbolProvider {
    func detectSymbol(in line: String, at location: Int, lineIndex _: Int, fullLine: String) -> DocumentSymbol? {
        // Class detection
        if line.hasPrefix("class ") {
            return extractSymbol(from: line, prefix: "class ", kind: .class, at: location, fullLine: fullLine)
        }

        // Function detection
        if line.hasPrefix("def ") {
            return extractSymbol(from: line, prefix: "def ", kind: .function, at: location, fullLine: fullLine)
        }

        // Async function detection
        if line.hasPrefix("async def ") {
            return extractSymbol(from: line, prefix: "async def ", kind: .function, at: location, fullLine: fullLine)
        }

        return nil
    }
}
