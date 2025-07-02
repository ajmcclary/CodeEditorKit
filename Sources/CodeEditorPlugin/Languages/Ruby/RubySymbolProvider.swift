import Foundation

/// Ruby symbol provider for detecting Ruby classes, modules, methods, and constants
struct RubySymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectRubySymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }
            
            currentLocation += line.count + 1
        }
        
        return symbols
    }
    
    private func detectRubySymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Skip comments and empty lines
        if trimmed.hasPrefix("#") || trimmed.isEmpty {
            return nil
        }
        
        // Class detection
        if trimmed.hasPrefix("class ") {
            return extractRubyClass(from: trimmed, at: location, fullLine: line)
        }
        
        // Module detection
        if trimmed.hasPrefix("module ") {
            return extractRubyModule(from: trimmed, at: location, fullLine: line)
        }
        
        // Method detection
        if trimmed.hasPrefix("def ") {
            return extractRubyMethod(from: trimmed, at: location, fullLine: line)
        }
        
        // Constant detection (uppercase)
        if let constantSymbol = extractRubyConstant(from: trimmed, at: location, fullLine: line) {
            return constantSymbol
        }
        
        // Instance variable detection
        if let instanceVar = extractInstanceVariable(from: trimmed, at: location, fullLine: line) {
            return instanceVar
        }
        
        // Class variable detection
        if let classVar = extractClassVariable(from: trimmed, at: location, fullLine: line) {
            return classVar
        }
        
        // Attribute accessor detection
        if let accessor = extractAttributeAccessor(from: trimmed, at: location, fullLine: line) {
            return accessor
        }
        
        return nil
    }
    
    private func extractRubyClass(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let afterClass = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces) // Drop "class "
        
        // Extract class name (before < or end of line)
        let className: String
        if let inheritanceIndex = afterClass.firstIndex(of: "<") {
            className = String(afterClass.prefix(upTo: inheritanceIndex)).trimmingCharacters(in: .whitespaces)
        } else {
            className = afterClass.prefix { !$0.isWhitespace }.trimmingCharacters(in: .whitespaces)
        }
        
        guard !className.isEmpty else { return nil }
        
        // Check for inheritance
        var detail = "class"
        if let inheritanceIndex = afterClass.firstIndex(of: "<") {
            let superclass = String(afterClass.suffix(from: afterClass.index(after: inheritanceIndex))).trimmingCharacters(in: .whitespaces)
            if !superclass.isEmpty {
                detail += " < \(superclass)"
            }
        }
        
        return DocumentSymbol(
            name: className,
            kind: .class,
            range: NSRange(location: location, length: fullLine.count),
            detail: detail
        )
    }
    
    private func extractRubyModule(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let afterModule = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces) // Drop "module "
        let moduleName = afterModule.prefix { !$0.isWhitespace }.trimmingCharacters(in: .whitespaces)
        
        guard !moduleName.isEmpty else { return nil }
        
        return DocumentSymbol(
            name: String(moduleName),
            kind: .namespace,
            range: NSRange(location: location, length: fullLine.count),
            detail: "module"
        )
    }
    
    private func extractRubyMethod(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let afterDef = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces) // Drop "def "
        
        // Extract method name (before parentheses or parameters)
        let methodNameAndParams: String
        if let parenIndex = afterDef.firstIndex(of: "(") {
            methodNameAndParams = String(afterDef.prefix(upTo: parenIndex))
        } else {
            methodNameAndParams = afterDef.prefix { !$0.isWhitespace }.trimmingCharacters(in: .whitespaces)
        }
        
        let methodName = String(methodNameAndParams).trimmingCharacters(in: .whitespaces)
        guard !methodName.isEmpty else { return nil }
        
        // Determine method type
        let kind: DocumentSymbolKind
        let detail: String
        
        if methodName.hasPrefix("self.") {
            kind = .function // Class method
            detail = "class method"
        } else if methodName == "initialize" {
            kind = .constructor
            detail = "constructor"
        } else if methodName.hasSuffix("?") {
            kind = .method
            detail = "predicate method"
        } else if methodName.hasSuffix("!") {
            kind = .method
            detail = "destructive method"
        } else {
            kind = .method
            detail = "instance method"
        }
        
        return DocumentSymbol(
            name: methodName,
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            detail: detail
        )
    }
    
    private func extractRubyConstant(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Look for constant assignment (uppercase start)
        if line.contains("=") && !line.contains("==") && !line.contains("!=") && !line.contains("<=") && !line.contains(">=") {
            if let equalIndex = line.firstIndex(of: "=") {
                let beforeEqual = String(line.prefix(upTo: equalIndex)).trimmingCharacters(in: .whitespaces)
                
                // Check if it's a constant (starts with uppercase)
                if let firstChar = beforeEqual.first, firstChar.isUppercase {
                    let constantName = beforeEqual.components(separatedBy: .whitespaces).last ?? beforeEqual
                    
                    if constantName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                        let afterEqual = String(line.suffix(from: line.index(after: equalIndex))).trimmingCharacters(in: .whitespaces)
                        let preview = String(afterEqual.prefix(30))
                        
                        return DocumentSymbol(
                            name: constantName,
                            kind: .constant,
                            range: NSRange(location: location, length: fullLine.count),
                            detail: "constant = \(preview)"
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractInstanceVariable(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Look for @variable assignments
        if line.contains("@") && line.contains("=") && !line.contains("@@") {
            if let atIndex = line.firstIndex(of: "@"),
               let equalIndex = line.firstIndex(of: "="),
               atIndex < equalIndex {
                let varPart = String(line[atIndex..<equalIndex]).trimmingCharacters(in: .whitespaces)
                
                if varPart.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "@" }) {
                    return DocumentSymbol(
                        name: varPart,
                        kind: .field,
                        range: NSRange(location: location, length: fullLine.count),
                        detail: "instance variable"
                    )
                }
            }
        }
        
        return nil
    }
    
    private func extractClassVariable(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Look for @@variable assignments
        if line.contains("@@") && line.contains("=") {
            if let doubleAtRange = line.range(of: "@@"),
               let equalIndex = line.firstIndex(of: "="),
               doubleAtRange.upperBound < equalIndex {
                let varPart = String(line[doubleAtRange.lowerBound..<equalIndex]).trimmingCharacters(in: .whitespaces)
                
                return DocumentSymbol(
                    name: varPart,
                    kind: .variable,
                    range: NSRange(location: location, length: fullLine.count),
                    detail: "class variable"
                )
            }
        }
        
        return nil
    }
    
    private func extractAttributeAccessor(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        let accessorKeywords = ["attr_reader", "attr_writer", "attr_accessor"]
        
        for keyword in accessorKeywords where line.trimmingCharacters(in: .whitespaces).hasPrefix(keyword) {
            let afterKeyword = String(line.dropFirst(keyword.count)).trimmingCharacters(in: .whitespaces)
            
            // Extract attribute names
            let attributesPart = afterKeyword.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: ",", with: " ")
            let attributes = attributesPart.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            
            if let firstAttribute = attributes.first {
                let detail = "\(keyword) \(attributes.joined(separator: ", "))"
                
                return DocumentSymbol(
                    name: firstAttribute,
                    kind: .property,
                    range: NSRange(location: location, length: fullLine.count),
                    detail: detail
                )
            }
        }
        
        return nil
    }
}
