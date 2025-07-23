import Foundation

/// SQL symbol provider for detecting SQL objects and statements
struct SQLSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let statements = splitSQLStatements(text)
        var currentLocation = 0

        for statement in statements {
            if let symbol = detectSQLSymbol(in: statement, at: currentLocation) {
                symbols.append(symbol)
            }
            currentLocation += statement.count + 1
        }

        return symbols
    }

    private func splitSQLStatements(_ text: String) -> [String] {
        // Split by semicolons that are not inside quotes
        var statements: [String] = []
        var currentStatement = ""
        var inSingleQuotes = false
        var inDoubleQuotes = false
        var inComment = false

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let processedLine = line

            // Handle line comments
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("--") {
                inComment = true
            }

            if inComment {
                inComment = false
                continue
            }

            for char in processedLine {
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

        return statements
    }

    private func detectSQLSymbol(in statement: String, at location: Int) -> DocumentSymbol? {
        let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        let upperStatement = trimmed.uppercased()

        // Skip comments and empty statements
        if trimmed.hasPrefix("--") || trimmed.hasPrefix("/*") || trimmed.isEmpty {
            return nil
        }

        // Detect different SQL statement types
        if upperStatement.hasPrefix("CREATE TABLE") {
            return extractCreateTable(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("CREATE VIEW") {
            return extractCreateView(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("CREATE INDEX") {
            return extractCreateIndex(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("CREATE PROCEDURE") || upperStatement.hasPrefix("CREATE PROC") {
            return extractCreateProcedure(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("CREATE FUNCTION") {
            return extractCreateFunction(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("SELECT") {
            return extractSelect(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("INSERT") {
            return extractInsert(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("UPDATE") {
            return extractUpdate(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("DELETE") {
            return extractDelete(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("ALTER TABLE") {
            return extractAlterTable(from: trimmed, at: location)
        } else if upperStatement.hasPrefix("DROP") {
            return extractDrop(from: trimmed, at: location)
        }

        return nil
    }

    private func extractCreateTable(from statement: String, at location: Int) -> DocumentSymbol? {
        let tableName = extractObjectName(from: statement, afterKeyword: "CREATE TABLE")

        return DocumentSymbol(
            name: "TABLE \(tableName)",
            kind: .class,
            range: NSRange(location: location, length: statement.count),
            detail: "Create table statement"
        )
    }

    private func extractCreateView(from statement: String, at location: Int) -> DocumentSymbol? {
        let viewName = extractObjectName(from: statement, afterKeyword: "CREATE VIEW")

        return DocumentSymbol(
            name: "VIEW \(viewName)",
            kind: .interface,
            range: NSRange(location: location, length: statement.count),
            detail: "Create view statement"
        )
    }

    private func extractCreateIndex(from statement: String, at location: Int) -> DocumentSymbol? {
        let indexName = extractObjectName(from: statement, afterKeyword: "CREATE INDEX")

        return DocumentSymbol(
            name: "INDEX \(indexName)",
            kind: .property,
            range: NSRange(location: location, length: statement.count),
            detail: "Create index statement"
        )
    }

    private func extractCreateProcedure(from statement: String, at location: Int) -> DocumentSymbol? {
        let keyword = statement.uppercased().contains("CREATE PROCEDURE") ? "CREATE PROCEDURE" : "CREATE PROC"
        let procName = extractObjectName(from: statement, afterKeyword: keyword)

        return DocumentSymbol(
            name: "PROC \(procName)",
            kind: .function,
            range: NSRange(location: location, length: statement.count),
            detail: "Create procedure statement"
        )
    }

    private func extractCreateFunction(from statement: String, at location: Int) -> DocumentSymbol? {
        let funcName = extractObjectName(from: statement, afterKeyword: "CREATE FUNCTION")

        return DocumentSymbol(
            name: "FUNC \(funcName)",
            kind: .function,
            range: NSRange(location: location, length: statement.count),
            detail: "Create function statement"
        )
    }

    private func extractSelect(from statement: String, at location: Int) -> DocumentSymbol? {
        let tables = extractTablesFromSelect(statement)
        let tableList = tables.joined(separator: ", ")

        return DocumentSymbol(
            name: "SELECT from \(tableList.isEmpty ? "unknown" : tableList)",
            kind: .method,
            range: NSRange(location: location, length: statement.count),
            detail: "Select statement"
        )
    }

    private func extractInsert(from statement: String, at location: Int) -> DocumentSymbol? {
        let tableName = extractTableFromDML(statement, keyword: "INSERT INTO")

        return DocumentSymbol(
            name: "INSERT into \(tableName)",
            kind: .method,
            range: NSRange(location: location, length: statement.count),
            detail: "Insert statement"
        )
    }

    private func extractUpdate(from statement: String, at location: Int) -> DocumentSymbol? {
        let tableName = extractTableFromDML(statement, keyword: "UPDATE")

        return DocumentSymbol(
            name: "UPDATE \(tableName)",
            kind: .method,
            range: NSRange(location: location, length: statement.count),
            detail: "Update statement"
        )
    }

    private func extractDelete(from statement: String, at location: Int) -> DocumentSymbol? {
        let tableName = extractTableFromDML(statement, keyword: "DELETE FROM")

        return DocumentSymbol(
            name: "DELETE from \(tableName)",
            kind: .method,
            range: NSRange(location: location, length: statement.count),
            detail: "Delete statement"
        )
    }

    private func extractAlterTable(from statement: String, at location: Int) -> DocumentSymbol? {
        let tableName = extractObjectName(from: statement, afterKeyword: "ALTER TABLE")

        return DocumentSymbol(
            name: "ALTER TABLE \(tableName)",
            kind: .method,
            range: NSRange(location: location, length: statement.count),
            detail: "Alter table statement"
        )
    }

    private func extractDrop(from statement: String, at location: Int) -> DocumentSymbol? {
        // Extract object type and name from DROP statement
        let upperStatement = statement.uppercased()
        let words = upperStatement.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        if words.count >= 3 {
            let objectType = words[1]
            let objectName = words[2]

            return DocumentSymbol(
                name: "DROP \(objectType) \(objectName)",
                kind: .method,
                range: NSRange(location: location, length: statement.count),
                detail: "Drop statement"
            )
        }

        return DocumentSymbol(
            name: "DROP statement",
            kind: .method,
            range: NSRange(location: location, length: statement.count),
            detail: "Drop statement"
        )
    }

    private func extractObjectName(from statement: String, afterKeyword keyword: String) -> String {
        let upperStatement = statement.uppercased()
        let upperKeyword = keyword.uppercased()

        guard let keywordRange = upperStatement.range(of: upperKeyword) else {
            return "unknown"
        }

        let afterKeyword = String(statement[keywordRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let objectName = afterKeyword.prefix { !$0.isWhitespace && $0 != "(" }

        return String(objectName).trimmingCharacters(in: .whitespaces)
    }

    private func extractTablesFromSelect(_ statement: String) -> [String] {
        let upperStatement = statement.uppercased()

        // Find FROM clause
        guard let fromRange = upperStatement.range(of: " FROM ") else {
            return []
        }

        let afterFrom = String(statement[fromRange.upperBound...])

        // Extract until WHERE, GROUP BY, ORDER BY, etc.
        let stopKeywords = [" WHERE ", " GROUP BY ", " ORDER BY ", " HAVING ", " UNION ", " LIMIT "]
        var tablesPart = afterFrom

        for keyword in stopKeywords {
            if let range = afterFrom.uppercased().range(of: keyword) {
                tablesPart = String(afterFrom[..<range.lowerBound])
                break
            }
        }

        // Split by commas and clean up
        return tablesPart.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func extractTableFromDML(_ statement: String, keyword: String) -> String {
        extractObjectName(from: statement, afterKeyword: keyword)
    }
}
