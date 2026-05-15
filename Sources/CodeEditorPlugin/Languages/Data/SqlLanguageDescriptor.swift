import Foundation

extension LanguageDescriptor {
    // ── SQL ────────────────────────────────────────────────────────
    static let sqlDescriptor = Self(
            language: .sql,
            displayName: "SQL",
            fileExtensions: ["sql"],
            lspIdentifier: "sql",
            usesRegexHighlighter: true,
            lineComment: "--",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["'"],
            caseInsensitiveKeywords: true,
            keywords: [
                "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
                "CREATE", "TABLE", "DROP", "ALTER", "INDEX", "VIEW", "JOIN", "INNER", "LEFT",
                "RIGHT", "OUTER", "ON", "AND", "OR", "NOT", "NULL", "IS", "IN", "LIKE", "BETWEEN",
                "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "DISTINCT",
                "AS", "CASE", "WHEN", "THEN", "ELSE", "END", "PRIMARY", "KEY", "FOREIGN",
                "REFERENCES", "CONSTRAINT", "DEFAULT", "AUTO_INCREMENT", "UNIQUE", "CHECK"
            ],
            types: [
                "INT", "INTEGER", "BIGINT", "SMALLINT", "TINYINT", "FLOAT", "DOUBLE", "DECIMAL",
                "NUMERIC", "CHAR", "VARCHAR", "TEXT", "DATE", "TIME", "DATETIME", "TIMESTAMP",
                "BOOLEAN", "BLOB", "CLOB", "JSON"
            ],
            functions: [
                "COUNT", "SUM", "AVG", "MIN", "MAX", "CONCAT", "SUBSTRING", "LENGTH", "UPPER",
                "LOWER", "TRIM", "COALESCE", "NULLIF", "CAST", "CONVERT", "NOW", "CURRENT_DATE",
                "CURRENT_TIME", "CURRENT_TIMESTAMP"
            ],
            literals: ["TRUE", "FALSE", "NULL"],
            triggerCharacters: [" ", "(", ","],
            snippets: DescriptorSnippetData.sql,
            memberCompletions: nil,
            commonModules: [],
            parserName: "sql",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
