import Foundation

/// SQL folding provider for detecting stored procedures, functions, and complex statements
struct SQLFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        let statements = splitSQLStatements(text)
        var currentLocation = 0

        for statement in statements {
            if let region = detectSQLFoldableRegion(in: statement, at: currentLocation) {
                regions.append(region)
            }
            currentLocation += statement.count + 1
        }

        // Also detect BEGIN/END blocks within statements
        regions.append(contentsOf: detectBeginEndBlocks(in: text))

        return regions
    }

    private func splitSQLStatements(_ text: String) -> [String] {
        var statements: [String] = []
        var currentStatement = ""
        var inSingleQuotes = false
        var inDoubleQuotes = false

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            // Skip line comments
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("--") {
                continue
            }

            for char in line {
                switch char {
                case "'":
                    if !inDoubleQuotes { inSingleQuotes.toggle() }
                    currentStatement.append(char)

                case "\"":
                    if !inSingleQuotes { inDoubleQuotes.toggle() }
                    currentStatement.append(char)

                case ";":
                    if !inSingleQuotes && !inDoubleQuotes {
                        if !currentStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            statements.append(currentStatement.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        currentStatement = ""
                    } else {
                        currentStatement.append(char)
                    }

                default:
                    currentStatement.append(char)
                }
            }

            currentStatement.append("\n")
        }

        // Add the last statement if it doesn't end with semicolon
        if !currentStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            statements.append(currentStatement.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return statements.filter { $0.components(separatedBy: .newlines).count >= 3 } // Only multi-line statements
    }

    private func detectSQLFoldableRegion(in statement: String, at location: Int) -> FoldableRegion? {
        let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        let upperStatement = trimmed.uppercased()

        // Stored procedure creation
        if upperStatement.hasPrefix("CREATE PROCEDURE") || upperStatement.hasPrefix("CREATE PROC") {
            let procedureName = extractObjectName(from: trimmed, afterKeyword: "CREATE PROCEDURE") ??
                               extractObjectName(from: trimmed, afterKeyword: "CREATE PROC")
            return FoldableRegion(
                range: NSRange(location: location, length: statement.count),
                title: "PROCEDURE \(procedureName ?? "unknown")",
                type: .function
            )
        }

        // Function creation
        if upperStatement.hasPrefix("CREATE FUNCTION") {
            let functionName = extractObjectName(from: trimmed, afterKeyword: "CREATE FUNCTION")
            return FoldableRegion(
                range: NSRange(location: location, length: statement.count),
                title: "FUNCTION \(functionName ?? "unknown")",
                type: .function
            )
        }

        // Trigger creation
        if upperStatement.hasPrefix("CREATE TRIGGER") {
            let triggerName = extractObjectName(from: trimmed, afterKeyword: "CREATE TRIGGER")
            return FoldableRegion(
                range: NSRange(location: location, length: statement.count),
                title: "TRIGGER \(triggerName ?? "unknown")",
                type: .function
            )
        }

        // View creation
        if upperStatement.hasPrefix("CREATE VIEW") {
            let viewName = extractObjectName(from: trimmed, afterKeyword: "CREATE VIEW")
            return FoldableRegion(
                range: NSRange(location: location, length: statement.count),
                title: "VIEW \(viewName ?? "unknown")",
                type: .class
            )
        }

        // Complex SELECT with CTEs or subqueries
        if upperStatement.hasPrefix("WITH ") ||
           (upperStatement.hasPrefix("SELECT") && (upperStatement.contains("UNION") || upperStatement.contains("JOIN"))) {
            return FoldableRegion(
                range: NSRange(location: location, length: statement.count),
                title: "Complex SELECT",
                type: .block
            )
        }

        // Large INSERT statements
        if upperStatement.hasPrefix("INSERT") && statement.components(separatedBy: .newlines).count >= 5 {
            let tableName = extractTableFromDML(statement, keyword: "INSERT INTO")
            return FoldableRegion(
                range: NSRange(location: location, length: statement.count),
                title: "INSERT into \(tableName ?? "table")",
                type: .block
            )
        }

        return nil
    }

    private func detectBeginEndBlocks(in text: String) -> [FoldableRegion] {
        var regions: [FoldableRegion] = []

        // Find BEGIN/END pairs
        var beginStack: [(location: Int, title: String)] = []
        var currentLocation = 0

        let lines = text.components(separatedBy: .newlines)

        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces).uppercased()

            if trimmed.hasPrefix("BEGIN") {
                let title = extractBeginTitle(from: line, lineIndex: lineIndex, lines: lines)
                beginStack.append((location: currentLocation, title: title))
            }

            if trimmed == "END" || trimmed.hasPrefix("END;") {
                if let begin = beginStack.popLast() {
                    let endLocation = currentLocation + line.count
                    let range = NSRange(location: begin.location, length: endLocation - begin.location)

                    regions.append(FoldableRegion(
                        range: range,
                        title: begin.title,
                        type: .block
                    ))
                }
            }

            currentLocation += line.count + 1
        }

        return regions
    }

    private func extractBeginTitle(from _: String, lineIndex: Int, lines: [String]) -> String {
        // Look at previous lines to determine context
        let previousLines = lines.prefix(lineIndex).suffix(3) // Last 3 lines before BEGIN
        let context = previousLines.joined(separator: " ").uppercased()

        if context.contains("CREATE PROCEDURE") || context.contains("CREATE PROC") {
            return "procedure body"
        } else if context.contains("CREATE FUNCTION") {
            return "function body"
        } else if context.contains("CREATE TRIGGER") {
            return "trigger body"
        } else if context.contains("IF") {
            return "if block"
        } else if context.contains("WHILE") {
            return "while loop"
        } else if context.contains("TRY") {
            return "try block"
        } else if context.contains("CATCH") {
            return "catch block"
        } else {
            return "BEGIN block"
        }
    }

    private func extractObjectName(from statement: String, afterKeyword keyword: String) -> String? {
        let upperStatement = statement.uppercased()
        let upperKeyword = keyword.uppercased()

        guard let keywordRange = upperStatement.range(of: upperKeyword) else {
            return nil
        }

        let afterKeyword = String(statement[keywordRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let objectName = afterKeyword.prefix { !$0.isWhitespace && $0 != "(" }

        return String(objectName).trimmingCharacters(in: .whitespaces)
    }

    private func extractTableFromDML(_ statement: String, keyword: String) -> String? {
        extractObjectName(from: statement, afterKeyword: keyword)
    }
}
