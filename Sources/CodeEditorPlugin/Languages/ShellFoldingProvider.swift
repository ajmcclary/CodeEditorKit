import CodeEditorTextModel
import Foundation

/// Shell script folding provider for detecting functions and control structures
package struct ShellFoldingProvider: CodeFoldingProvider {
    package init() {}

    package func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        // Stack to track nested structures
        var blockStack: [(type: FoldingType, startLine: Int, startLocation: Int, title: String)] = []

        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.hasPrefix("#") || trimmed.isEmpty {
                currentLocation += TextRangeUtilities.utf16Length(of: line) + 1
                continue
            }

            // Function detection
            if let functionRegion = detectShellFunction(line: trimmed, lineIndex: lineIndex, location: currentLocation) {
                blockStack.append((type: .function, startLine: lineIndex, startLocation: currentLocation, title: functionRegion.title))
            }

            // Control structure detection
            if let controlStart = detectControlStart(line: trimmed) {
                blockStack.append((type: .block, startLine: lineIndex, startLocation: currentLocation, title: controlStart))
            }

            // End detection
            if isBlockEnd(line: trimmed) {
                if let block = blockStack.popLast() {
                    let endLocation = currentLocation + TextRangeUtilities.utf16Length(of: line)
                    let range = NSRange(location: block.startLocation, length: endLocation - block.startLocation)

                    // Only add regions with minimum line count
                    if lineIndex - block.startLine >= 2 {
                        regions.append(FoldableRegion(
                            range: range,
                            title: block.title,
                            type: block.type
                        ))
                    }
                }
            }

            // Case statement detection
            if trimmed.hasPrefix("case ") && trimmed.hasSuffix(" in") {
                blockStack.append((type: .block, startLine: lineIndex, startLocation: currentLocation, title: "case statement"))
            }

            // Subshell detection
            if trimmed == "(" {
                blockStack.append((type: .block, startLine: lineIndex, startLocation: currentLocation, title: "subshell"))
            }

            if trimmed == ")" && !blockStack.isEmpty {
                if let block = blockStack.last, block.title == "subshell" {
                    blockStack.removeLast()
                    let endLocation = currentLocation + TextRangeUtilities.utf16Length(of: line)
                    let range = NSRange(location: block.startLocation, length: endLocation - block.startLocation)

                    if lineIndex - block.startLine >= 1 {
                        regions.append(FoldableRegion(
                            range: range,
                            title: "subshell",
                            type: .block
                        ))
                    }
                }
            }

            currentLocation += TextRangeUtilities.utf16Length(of: line) + 1
        }

        return regions
    }

    private func detectShellFunction(line: String, lineIndex _: Int, location: Int) -> FoldableRegion? {
        // Function form 1: function name() { ... }
        if line.hasPrefix("function ") && line.contains("(") && line.contains(")") {
            let afterFunction = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            if let parenIndex = afterFunction.firstIndex(of: "(") {
                let functionName = String(afterFunction.prefix(upTo: parenIndex)).trimmingCharacters(in: .whitespaces)
                if !functionName.isEmpty {
                    return FoldableRegion(
                        range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: line)),
                        title: "function \(functionName)",
                        type: .function
                    )
                }
            }
        }

        // Function form 2: name() { ... }
        if line.contains("()") && line.contains("{") && !line.contains("=") {
            if let parenRange = line.range(of: "()") {
                let beforeParen = String(line.prefix(upTo: parenRange.lowerBound)).trimmingCharacters(in: .whitespaces)
                let parts = beforeParen.components(separatedBy: .whitespaces)
                if let functionName = parts.last, !functionName.isEmpty {
                    if functionName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) {
                        return FoldableRegion(
                            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: line)),
                            title: "function \(functionName)",
                            type: .function
                        )
                    }
                }
            }
        }

        return nil
    }

    private func detectControlStart(line: String) -> String? {
        // if statements
        if line.hasPrefix("if ") && line.hasSuffix("; then") {
            return "if statement"
        }

        if line == "then" {
            return "then block"
        }

        // for loops
        if line.hasPrefix("for ") && line.contains(" in ") {
            return "for loop"
        }

        // while loops
        if line.hasPrefix("while ") && line.hasSuffix("; do") {
            return "while loop"
        }

        if line == "do" {
            return "do block"
        }

        // until loops
        if line.hasPrefix("until ") && line.hasSuffix("; do") {
            return "until loop"
        }

        // select statements
        if line.hasPrefix("select ") && line.contains(" in ") {
            return "select statement"
        }

        // Opening brace
        if line == "{" {
            return "block"
        }

        return nil
    }

    private func isBlockEnd(line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return ["fi", "done", "esac", "}"].contains(trimmed)
    }
}
