import Foundation

/// SQL folding provider for detecting stored procedures, functions, and complex statements
struct SQLFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        let statements = SQLParsingUtility.splitStatements(text, minimumLines: 3)
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

    private func detectSQLFoldableRegion(in statement: String, at location: Int) -> FoldableRegion? {
        let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        let upperStatement = trimmed.uppercased()

        // Stored procedure creation
        if upperStatement.hasPrefix("CREATE PROCEDURE") || upperStatement.hasPrefix("CREATE PROC") {
            let procedureName = SQLParsingUtility.extractObjectName(from: trimmed, afterKeyword: "CREATE PROCEDURE") ??
                               SQLParsingUtility.extractObjectName(from: trimmed, afterKeyword: "CREATE PROC")
            return FoldableRegion(
                range: NSRange(location: location, length: statement.count),
                title: "PROCEDURE \(procedureName ?? "unknown")",
                type: .function
            )
        }

        // Function creation
        if upperStatement.hasPrefix("CREATE FUNCTION") {
            let functionName = SQLParsingUtility.extractObjectName(from: trimmed, afterKeyword: "CREATE FUNCTION")
            return FoldableRegion(
                range: NSRange(location: location, length: statement.count),
                title: "FUNCTION \(functionName ?? "unknown")",
                type: .function
            )
        }

        // Trigger creation
        if upperStatement.hasPrefix("CREATE TRIGGER") {
            let triggerName = SQLParsingUtility.extractObjectName(from: trimmed, afterKeyword: "CREATE TRIGGER")
            return FoldableRegion(
                range: NSRange(location: location, length: statement.count),
                title: "TRIGGER \(triggerName ?? "unknown")",
                type: .function
            )
        }

        // View creation
        if upperStatement.hasPrefix("CREATE VIEW") {
            let viewName = SQLParsingUtility.extractObjectName(from: trimmed, afterKeyword: "CREATE VIEW")
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
            let tableName = SQLParsingUtility.extractObjectName(from: statement, afterKeyword: "INSERT INTO")
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
}
