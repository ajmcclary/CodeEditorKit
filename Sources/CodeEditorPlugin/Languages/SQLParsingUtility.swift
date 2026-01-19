import Foundation

/// Utility for parsing SQL text, shared between SQLSymbolProvider and SQLFoldingProvider
public enum SQLParsingUtility {
    // MARK: - Statement Splitting

    /// Split SQL text into individual statements
    /// - Parameters:
    ///   - text: The SQL text to parse
    ///   - minimumLines: Minimum lines required for a statement (default: 1)
    /// - Returns: Array of SQL statements
    public static func splitStatements(_ text: String, minimumLines: Int = 1) -> [String] {
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

        // Filter by minimum lines if specified
        if minimumLines > 1 {
            return statements.filter { $0.components(separatedBy: .newlines).count >= minimumLines }
        }

        return statements
    }

    // MARK: - Object Name Extraction

    /// Extract object name after a keyword in an SQL statement
    /// - Parameters:
    ///   - statement: The SQL statement to parse
    ///   - keyword: The keyword to search for (case-insensitive)
    /// - Returns: The object name if found, nil otherwise
    public static func extractObjectName(from statement: String, afterKeyword keyword: String) -> String? {
        let upperStatement = statement.uppercased()
        let upperKeyword = keyword.uppercased()

        guard let keywordRange = upperStatement.range(of: upperKeyword) else {
            return nil
        }

        let afterKeyword = String(statement[keywordRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let objectName = afterKeyword.prefix { !$0.isWhitespace && $0 != "(" }
        let result = String(objectName).trimmingCharacters(in: .whitespaces)

        return result.isEmpty ? nil : result
    }

    /// Extract object name after a keyword in an SQL statement, returning a default value if not found
    /// - Parameters:
    ///   - statement: The SQL statement to parse
    ///   - keyword: The keyword to search for (case-insensitive)
    ///   - defaultValue: Value to return if object name not found (default: "unknown")
    /// - Returns: The object name or the default value
    public static func extractObjectName(
        from statement: String,
        afterKeyword keyword: String,
        defaultValue: String
    ) -> String {
        extractObjectName(from: statement, afterKeyword: keyword) ?? defaultValue
    }
}
