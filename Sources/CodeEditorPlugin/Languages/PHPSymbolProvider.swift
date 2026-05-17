import CodeEditorTextModel
import Foundation

/// PHP symbol provider for detecting PHP classes, functions, methods, and variables
package struct PHPSymbolProvider: StatefulLineBasedSymbolProvider {
    package struct State {
        var inClass = false
        var inFunction = false
    }

    package init() {}

    package func makeState() -> State { State() }

    package func detectSymbols(
        in line: String,
        at location: Int,
        lineIndex _: Int,
        fullLine: String,
        state: inout State
    ) -> [DocumentSymbol] {
        // Skip comments and empty lines
        if line.hasPrefix("//") || line.hasPrefix("#") || line.hasPrefix("/*") || line.isEmpty {
            return []
        }

        // Track context
        if line.contains("}") {
            if state.inFunction {
                state.inFunction = false
            } else if state.inClass {
                state.inClass = false
            }
        }

        // Class detection
        if line.hasPrefix("class ") || line.contains(" class ") {
            state.inClass = true
            return extractPHPClass(from: line, at: location, fullLine: fullLine).map { [$0] } ?? []
        }

        // Interface detection
        if line.hasPrefix("interface ") || line.contains(" interface ") {
            return extractPHPInterface(from: line, at: location, fullLine: fullLine).map { [$0] } ?? []
        }

        // Trait detection
        if line.hasPrefix("trait ") || line.contains(" trait ") {
            return extractPHPTrait(from: line, at: location, fullLine: fullLine).map { [$0] } ?? []
        }

        // Function detection
        if line.hasPrefix("function ") || line.contains(" function ") {
            if state.inClass {
                return extractPHPMethod(from: line, at: location, fullLine: fullLine).map { [$0] } ?? []
            } else {
                state.inFunction = true
                return extractPHPFunction(from: line, at: location, fullLine: fullLine).map { [$0] } ?? []
            }
        }

        // Constant detection
        if line.hasPrefix("const ") || line.contains(" const ") {
            return extractPHPConstant(from: line, at: location, fullLine: fullLine).map { [$0] } ?? []
        }

        // Property detection (in class context)
        if state.inClass && (line.hasPrefix("public ") || line.hasPrefix("private ") || line.hasPrefix("protected ") || line.hasPrefix("var ")) {
            return extractPHPProperty(from: line, at: location, fullLine: fullLine).map { [$0] } ?? []
        }

        // Global variable detection
        if !state.inClass && !state.inFunction && line.hasPrefix("$") && line.contains("=") {
            return extractPHPVariable(from: line, at: location, fullLine: fullLine).map { [$0] } ?? []
        }

        return []
    }

    private func extractPHPClass(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let className = extractPHPName(from: line, afterKeyword: "class")
        guard !className.isEmpty else { return nil }

        var detail = "class"

        // Check for inheritance
        if line.contains(" extends ") {
            if let extendsRange = line.range(of: " extends ") {
                let afterExtends = String(line[extendsRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                let parentClass = afterExtends.prefix { !$0.isWhitespace && $0 != "{" && $0 != "i" } // "i" for "implements"
                if !parentClass.isEmpty {
                    detail += " extends \(parentClass)"
                }
            }
        }

        // Check for interfaces
        if line.contains(" implements ") {
            if let implementsRange = line.range(of: " implements ") {
                let afterImplements = String(line[implementsRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                let interfaces = afterImplements.prefix { $0 != "{" }
                if !interfaces.isEmpty {
                    detail += " implements \(interfaces)"
                }
            }
        }

        return DocumentSymbol(
            name: className,
            kind: .class,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: detail
        )
    }

    private func extractPHPInterface(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let interfaceName = extractPHPName(from: line, afterKeyword: "interface")
        guard !interfaceName.isEmpty else { return nil }

        return DocumentSymbol(
            name: interfaceName,
            kind: .interface,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: "interface"
        )
    }

    private func extractPHPTrait(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let traitName = extractPHPName(from: line, afterKeyword: "trait")
        guard !traitName.isEmpty else { return nil }

        return DocumentSymbol(
            name: traitName,
            kind: .module,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: "trait"
        )
    }

    private func extractPHPFunction(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let functionName = extractPHPName(from: line, afterKeyword: "function")
        guard !functionName.isEmpty else { return nil }

        return DocumentSymbol(
            name: functionName,
            kind: .function,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: "function"
        )
    }

    private func extractPHPMethod(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let methodName = extractPHPName(from: line, afterKeyword: "function")
        guard !methodName.isEmpty else { return nil }

        // Determine method visibility and type
        var detail = "method"
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("public ") {
            detail = "public method"
        } else if trimmed.hasPrefix("private ") {
            detail = "private method"
        } else if trimmed.hasPrefix("protected ") {
            detail = "protected method"
        } else if trimmed.hasPrefix("static ") || trimmed.contains(" static ") {
            detail = "static method"
        }

        if trimmed.contains(" static ") {
            detail = "static " + detail
        }

        let kind: DocumentSymbolKind = methodName == "__construct" ? .constructor : .method

        return DocumentSymbol(
            name: methodName,
            kind: kind,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: detail
        )
    }

    private func extractPHPConstant(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let constantName = extractPHPName(from: line, afterKeyword: "const")
        guard !constantName.isEmpty else { return nil }

        return DocumentSymbol(
            name: constantName,
            kind: .constant,
            range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
            detail: "constant"
        )
    }

    private func extractPHPProperty(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Extract property name after visibility modifier
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var detail = "property"
        var afterModifier = trimmed

        if trimmed.hasPrefix("public ") {
            detail = "public property"
            afterModifier = String(trimmed.dropFirst(7))
        } else if trimmed.hasPrefix("private ") {
            detail = "private property"
            afterModifier = String(trimmed.dropFirst(8))
        } else if trimmed.hasPrefix("protected ") {
            detail = "protected property"
            afterModifier = String(trimmed.dropFirst(10))
        } else if trimmed.hasPrefix("var ") {
            detail = "public property"
            afterModifier = String(trimmed.dropFirst(4))
        }

        // Check for static
        if afterModifier.hasPrefix("static ") {
            detail = "static " + detail
            afterModifier = String(afterModifier.dropFirst(7))
        }

        // Extract variable name (starts with $)
        afterModifier = afterModifier.trimmingCharacters(in: .whitespaces)
        if afterModifier.hasPrefix("$") {
            let propertyName = afterModifier.prefix { !$0.isWhitespace && $0 != "=" && $0 != ";" }

            return DocumentSymbol(
                name: String(propertyName),
                kind: .property,
                range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                detail: detail
            )
        }

        return nil
    }

    private func extractPHPVariable(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if let dollarIndex = trimmed.firstIndex(of: "$"),
           let equalIndex = trimmed.firstIndex(of: "="),
           dollarIndex < equalIndex {
            let varName = String(trimmed[dollarIndex..<equalIndex]).trimmingCharacters(in: .whitespaces)

            return DocumentSymbol(
                name: varName,
                kind: .variable,
                range: NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine)),
                detail: "global variable"
            )
        }

        return nil
    }

    private func extractPHPName(from line: String, afterKeyword keyword: String) -> String {
        guard let keywordRange = line.range(of: keyword, options: .caseInsensitive) else {
            return ""
        }

        let afterKeyword = String(line[keywordRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let name = afterKeyword.prefix { $0.isLetter || $0.isNumber || $0 == "_" }

        return String(name)
    }
}
