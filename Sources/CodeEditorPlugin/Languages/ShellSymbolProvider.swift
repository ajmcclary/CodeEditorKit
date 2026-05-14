import Foundation

/// Shell script symbol provider for detecting functions, variables, and aliases
struct ShellSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectShellSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }

            currentLocation += TextRangeUtilities.utf16Length(of: line) + 1
        }

        return symbols
    }

    private func detectShellSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip comments and empty lines
        if trimmed.hasPrefix("#") || trimmed.isEmpty {
            return nil
        }

        // Function detection (various forms)
        if let functionSymbol = extractShellFunction(from: trimmed, at: location, fullLine: line) {
            return functionSymbol
        }

        // Variable assignment detection
        if let variableSymbol = extractShellVariable(from: trimmed, at: location, fullLine: line) {
            return variableSymbol
        }

        // Alias detection
        if let aliasSymbol = extractShellAlias(from: trimmed, at: location, fullLine: line) {
            return aliasSymbol
        }

        // Export detection
        if let exportSymbol = extractShellExport(from: trimmed, at: location, fullLine: line) {
            return exportSymbol
        }

        return nil
    }

    private func extractShellFunction(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Function form 1: function name() { ... }
        if line.hasPrefix("function ") && line.contains("(") && line.contains(")") {
            let afterFunction = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            if let parenIndex = afterFunction.firstIndex(of: "(") {
                let functionName = String(afterFunction.prefix(upTo: parenIndex)).trimmingCharacters(in: .whitespaces)
                if !functionName.isEmpty {
                    return DocumentSymbol(
                        name: functionName,
                        kind: .function,
                        range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                        detail: "function"
                    )
                }
            }
        }

        // Function form 2: name() { ... }
        if line.contains("()") && line.contains("{") && !line.contains("=") {
            if let parenIndex = line.range(of: "()") {
                let beforeParen = String(line.prefix(upTo: parenIndex.lowerBound)).trimmingCharacters(in: .whitespaces)

                // Extract the function name (last word before parentheses)
                let parts = beforeParen.components(separatedBy: .whitespaces)
                if let functionName = parts.last, !functionName.isEmpty {
                    // Validate it's a valid function name
                    if functionName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) {
                        return DocumentSymbol(
                            name: functionName,
                            kind: .function,
                            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                            detail: "function"
                        )
                    }
                }
            }
        }

        return nil
    }

    private func extractShellVariable(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Variable assignment: VAR=value or var=value
        if line.contains("=") && !line.contains("==") && !line.contains("!=") && !line.contains("<=") && !line.contains(">=") {
            if let equalIndex = line.firstIndex(of: "=") {
                let beforeEqual = String(line.prefix(upTo: equalIndex)).trimmingCharacters(in: .whitespaces)

                // Check if it's a simple variable assignment (no spaces in the name part)
                if !beforeEqual.contains(" ") && !beforeEqual.isEmpty {
                    // Remove leading $ if present
                    let varName = beforeEqual.hasPrefix("$") ? String(beforeEqual.dropFirst()) : beforeEqual

                    // Validate variable name
                    if varName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                        let afterEqual = String(line.suffix(from: line.index(after: equalIndex))).trimmingCharacters(in: .whitespaces)
                        let preview = String(afterEqual.prefix(30))

                        let kind: DocumentSymbolKind = beforeEqual.allSatisfy { $0.isUppercase || $0 == "_" } ? .constant : .variable

                        return DocumentSymbol(
                            name: varName,
                            kind: kind,
                            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                            detail: "\(kind == .constant ? "constant" : "variable") = \(preview)"
                        )
                    }
                }
            }
        }

        return nil
    }

    private func extractShellAlias(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Alias detection: alias name='command'
        if line.hasPrefix("alias ") {
            let afterAlias = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)

            if let equalIndex = afterAlias.firstIndex(of: "=") {
                let aliasName = String(afterAlias.prefix(upTo: equalIndex)).trimmingCharacters(in: .whitespaces)
                let aliasValue = String(afterAlias.suffix(from: afterAlias.index(after: equalIndex))).trimmingCharacters(in: .whitespaces)

                if !aliasName.isEmpty {
                    let preview = String(aliasValue.prefix(30))

                    return DocumentSymbol(
                        name: aliasName,
                        kind: .property,
                        range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                        detail: "alias = \(preview)"
                    )
                }
            }
        }

        return nil
    }

    private func extractShellExport(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Export detection: export VAR=value or export VAR
        if line.hasPrefix("export ") {
            let afterExport = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)

            var varName: String
            var detail: String

            if afterExport.contains("=") {
                // export VAR=value
                if let equalIndex = afterExport.firstIndex(of: "=") {
                    varName = String(afterExport.prefix(upTo: equalIndex)).trimmingCharacters(in: .whitespaces)
                    let value = String(afterExport.suffix(from: afterExport.index(after: equalIndex))).trimmingCharacters(in: .whitespaces)
                    let preview = String(value.prefix(30))
                    detail = "export = \(preview)"
                } else {
                    return nil
                }
            } else {
                // export VAR
                varName = afterExport.prefix { !$0.isWhitespace }.trimmingCharacters(in: .whitespaces)
                detail = "export"
            }

            if !varName.isEmpty && varName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                return DocumentSymbol(
                    name: varName,
                    kind: .constant,
                    range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                    detail: detail
                )
            }
        }

        return nil
    }
}
