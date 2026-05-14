import Foundation

/// Ruby folding provider for detecting classes, modules, methods, and blocks
struct RubyFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0

        // Stack to track nested structures
        var blockStack: [(type: FoldingType, startLine: Int, startLocation: Int, title: String, keyword: String)] = []

        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.hasPrefix("#") || trimmed.isEmpty {
                currentLocation += TextRangeUtilities.utf16Length(of: line) + 1
                continue
            }

            // Check for block start
            if let blockInfo = detectBlockStart(trimmed: trimmed, line: line, lineIndex: lineIndex, currentLocation: currentLocation) {
                blockStack.append(blockInfo)
            }

            // End keyword detection
            if trimmed == "end" {
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

            // Rescue/ensure blocks within methods or begin blocks
            if trimmed.hasPrefix("rescue") && !blockStack.isEmpty {
                if let lastBlock = blockStack.last, ["def", "begin"].contains(lastBlock.keyword) {
                    // Start a rescue block
                    blockStack.append((type: .block, startLine: lineIndex, startLocation: currentLocation, title: "rescue block", keyword: "rescue"))
                }
            }

            if trimmed.hasPrefix("ensure") && !blockStack.isEmpty {
                // Close any rescue block and start ensure
                if let lastBlock = blockStack.last, lastBlock.keyword == "rescue" {
                    let rescueBlock = blockStack.removeLast()
                    let rescueEndLocation = currentLocation - 1
                    let rescueRange = NSRange(location: rescueBlock.startLocation, length: rescueEndLocation - rescueBlock.startLocation)

                    if lineIndex - rescueBlock.startLine >= 1 {
                        regions.append(FoldableRegion(
                            range: rescueRange,
                            title: rescueBlock.title,
                            type: rescueBlock.type
                        ))
                    }
                }

                blockStack.append((type: .block, startLine: lineIndex, startLocation: currentLocation, title: "ensure block", keyword: "ensure"))
            }

            currentLocation += TextRangeUtilities.utf16Length(of: line) + 1
        }

        return regions
    }

    private func detectBlockStart(trimmed: String, line: String, lineIndex: Int, currentLocation: Int) -> (type: FoldingType, startLine: Int, startLocation: Int, title: String, keyword: String)? {
        // Class detection
        if trimmed.hasPrefix("class ") {
            let className = extractRubyName(from: trimmed, afterKeyword: "class")
            return (type: .class, startLine: lineIndex, startLocation: currentLocation, title: "class \(className)", keyword: "class")
        }

        // Module detection
        if trimmed.hasPrefix("module ") {
            let moduleName = extractRubyName(from: trimmed, afterKeyword: "module")
            return (type: .class, startLine: lineIndex, startLocation: currentLocation, title: "module \(moduleName)", keyword: "module")
        }

        // Method detection
        if trimmed.hasPrefix("def ") {
            let methodName = extractRubyMethodName(from: trimmed)
            return (type: .method, startLine: lineIndex, startLocation: currentLocation, title: "def \(methodName)", keyword: "def")
        }

        // Begin block detection
        if trimmed == "begin" {
            return (type: .block, startLine: lineIndex, startLocation: currentLocation, title: "begin block", keyword: "begin")
        }

        // Case statement detection
        if trimmed.hasPrefix("case ") {
            let caseVar = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return (type: .block, startLine: lineIndex, startLocation: currentLocation, title: "case \(caseVar)", keyword: "case")
        }

        // If statement detection (only for multi-line if)
        if trimmed.hasPrefix("if ") && !trimmed.contains(" then ") && !line.contains(";") {
            let condition = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            let shortCondition = String(condition.prefix(30))
            return (type: .block, startLine: lineIndex, startLocation: currentLocation, title: "if \(shortCondition)", keyword: "if")
        }

        // Unless statement detection
        if trimmed.hasPrefix("unless ") && !line.contains(";") {
            let condition = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            let shortCondition = String(condition.prefix(30))
            return (type: .block, startLine: lineIndex, startLocation: currentLocation, title: "unless \(shortCondition)", keyword: "unless")
        }

        // While loop detection
        if trimmed.hasPrefix("while ") && !line.contains(";") {
            let condition = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            let shortCondition = String(condition.prefix(30))
            return (type: .block, startLine: lineIndex, startLocation: currentLocation, title: "while \(shortCondition)", keyword: "while")
        }

        // Until loop detection
        if trimmed.hasPrefix("until ") && !line.contains(";") {
            let condition = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            let shortCondition = String(condition.prefix(30))
            return (type: .block, startLine: lineIndex, startLocation: currentLocation, title: "until \(shortCondition)", keyword: "until")
        }

        // For loop detection
        if trimmed.hasPrefix("for ") && trimmed.contains(" in ") {
            let forPart = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            return (type: .block, startLine: lineIndex, startLocation: currentLocation, title: "for \(forPart)", keyword: "for")
        }

        // Block detection with do
        if trimmed.hasSuffix(" do") || trimmed.hasSuffix(" do |") || trimmed.contains("} do") {
            let blockTitle = extractBlockTitle(from: trimmed)
            return (type: .block, startLine: lineIndex, startLocation: currentLocation, title: blockTitle, keyword: "do")
        }

        return nil
    }

    private func extractRubyName(from line: String, afterKeyword keyword: String) -> String {
        let afterKeyword = String(line.dropFirst(keyword.count + 1)).trimmingCharacters(in: .whitespaces)

        // Handle inheritance (class Foo < Bar)
        if let inheritanceIndex = afterKeyword.firstIndex(of: "<") {
            return String(afterKeyword.prefix(upTo: inheritanceIndex)).trimmingCharacters(in: .whitespaces)
        }

        // Handle namespacing (module Foo::Bar)
        let name = afterKeyword.prefix { !$0.isWhitespace }
        return String(name)
    }

    private func extractRubyMethodName(from line: String) -> String {
        let afterDef = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces) // Drop "def "

        // Extract method name (before parentheses or parameters)
        let methodNameAndParams: String
        if let parenIndex = afterDef.firstIndex(of: "(") {
            methodNameAndParams = String(afterDef.prefix(upTo: parenIndex))
        } else {
            methodNameAndParams = afterDef.prefix { !$0.isWhitespace }.trimmingCharacters(in: .whitespaces)
        }

        return String(methodNameAndParams).trimmingCharacters(in: .whitespaces)
    }

    private func extractBlockTitle(from line: String) -> String {
        if line.hasSuffix(" do") {
            let beforeDo = String(line.dropLast(3)).trimmingCharacters(in: .whitespaces)

            // Extract the main part (method call or iterator)
            if beforeDo.contains(".") {
                let parts = beforeDo.components(separatedBy: ".")
                if let lastPart = parts.last {
                    return "\(lastPart) block"
                }
            }

            return "\(beforeDo) block"
        } else if line.hasSuffix(" do |") {
            let beforeDo = String(line.dropLast(4)).trimmingCharacters(in: .whitespaces)
            return "\(beforeDo) block"
        } else if line.contains("} do") {
            return "block with parameters"
        }

        return "block"
    }
}
