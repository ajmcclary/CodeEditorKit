import Foundation

// MARK: - SQL Completion Provider

/// Built-in completion provider for SQL language
@MainActor
public final class SQLCompletionProvider: CompletionProvider, @unchecked Sendable {
    public let id = "sql-builtin"
    public let supportedLanguages: [Language] = [.sql]
    public let triggerCharacters = [" ", ".", "(", ",", "=", "*"]
    public let supportsSnippets = true
    
    // SQL keywords (standard SQL)
    private let keywords = [
        // DDL
        "CREATE", "ALTER", "DROP", "TRUNCATE", "RENAME",
        // DML
        "SELECT", "INSERT", "UPDATE", "DELETE", "MERGE",
        // DCL
        "GRANT", "REVOKE",
        // TCL
        "COMMIT", "ROLLBACK", "SAVEPOINT", "SET",
        // Clauses
        "FROM", "WHERE", "GROUP BY", "HAVING", "ORDER BY", "LIMIT", "OFFSET",
        "JOIN", "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "FULL JOIN", "CROSS JOIN",
        "ON", "USING", "NATURAL", "UNION", "UNION ALL", "INTERSECT", "EXCEPT",
        // Conditions
        "AND", "OR", "NOT", "IN", "EXISTS", "BETWEEN", "LIKE", "IS", "NULL",
        "ANY", "ALL", "SOME", "UNIQUE",
        // Data types
        "INT", "INTEGER", "BIGINT", "SMALLINT", "TINYINT", "DECIMAL", "NUMERIC",
        "FLOAT", "REAL", "DOUBLE", "CHAR", "VARCHAR", "TEXT", "DATE", "TIME",
        "TIMESTAMP", "DATETIME", "BOOLEAN", "BLOB", "CLOB", "JSON", "XML",
        // Constraints
        "PRIMARY KEY", "FOREIGN KEY", "REFERENCES", "UNIQUE", "CHECK", "DEFAULT",
        "NOT NULL", "AUTO_INCREMENT", "IDENTITY",
        // Objects
        "TABLE", "VIEW", "INDEX", "SEQUENCE", "TRIGGER", "PROCEDURE", "FUNCTION",
        "DATABASE", "SCHEMA",
        // Other keywords
        "AS", "DISTINCT", "TOP", "INTO", "VALUES", "SET", "CASE", "WHEN", "THEN",
        "ELSE", "END", "BEGIN", "DECLARE", "IF", "WHILE", "FOR", "RETURN",
        "WITH", "RECURSIVE", "TEMPORARY", "CASCADE", "RESTRICT"
    ]
    
    // SQL functions
    private let functions = [
        // Aggregate functions
        "COUNT", "SUM", "AVG", "MIN", "MAX", "GROUP_CONCAT", "STRING_AGG",
        // String functions
        "CONCAT", "SUBSTRING", "SUBSTR", "LENGTH", "UPPER", "LOWER", "TRIM",
        "LTRIM", "RTRIM", "REPLACE", "REVERSE", "CHAR_LENGTH", "POSITION",
        "LOCATE", "INSTR", "LEFT", "RIGHT", "REPEAT", "SPACE", "ASCII",
        // Numeric functions
        "ABS", "CEIL", "CEILING", "FLOOR", "ROUND", "TRUNCATE", "MOD", "POWER",
        "SQRT", "EXP", "LOG", "LOG10", "SIGN", "RAND", "RANDOM",
        // Date/Time functions
        "NOW", "CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP", "DATE",
        "TIME", "YEAR", "MONTH", "DAY", "HOUR", "MINUTE", "SECOND",
        "DAYNAME", "MONTHNAME", "WEEK", "QUARTER", "DAYOFWEEK", "DAYOFYEAR",
        "DATE_ADD", "DATE_SUB", "DATEDIFF", "DATE_FORMAT", "STR_TO_DATE",
        // Conversion functions
        "CAST", "CONVERT", "COALESCE", "NULLIF", "IFNULL", "ISNULL", "NVL",
        // Window functions
        "ROW_NUMBER", "RANK", "DENSE_RANK", "PERCENT_RANK", "CUME_DIST",
        "NTILE", "LAG", "LEAD", "FIRST_VALUE", "LAST_VALUE", "NTH_VALUE",
        // JSON functions
        "JSON_EXTRACT", "JSON_OBJECT", "JSON_ARRAY", "JSON_VALID", "JSON_LENGTH",
        "JSON_TYPE", "JSON_SEARCH", "JSON_CONTAINS", "JSON_KEYS"
    ]
    
    // Common table and column name patterns
    private let commonTables = [
        "users", "user", "accounts", "account", "customers", "customer",
        "orders", "order", "products", "product", "items", "item",
        "categories", "category", "posts", "post", "comments", "comment",
        "employees", "employee", "departments", "department", "projects", "project",
        "transactions", "transaction", "payments", "payment", "invoices", "invoice",
        "settings", "config", "logs", "log", "sessions", "session"
    ]
    
    private let commonColumns = [
        "id", "uuid", "name", "title", "description", "email", "username",
        "password", "created_at", "updated_at", "deleted_at", "status",
        "is_active", "is_deleted", "type", "value", "amount", "price",
        "quantity", "date", "time", "timestamp", "user_id", "order_id",
        "product_id", "category_id", "parent_id", "sort_order", "position"
    ]
    
    // Database-specific keywords
    private let mysqlKeywords = [
        "AUTO_INCREMENT", "UNSIGNED", "ZEROFILL", "BINARY", "COLLATE",
        "CHARACTER SET", "ENGINE", "InnoDB", "MyISAM", "SHOW", "DESCRIBE",
        "EXPLAIN", "USE", "DELIMITER", "SOURCE"
    ]
    
    private let postgresKeywords = [
        "SERIAL", "BIGSERIAL", "SMALLSERIAL", "RETURNING", "VACUUM", "ANALYZE",
        "EXPLAIN ANALYZE", "COPY", "DO", "PERFORM", "RAISE", "EXCEPTION",
        "ARRAY", "JSONB", "UUID", "INET", "CIDR", "MACADDR"
    ]
    
    private let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "select",
            insertText: "SELECT ${1:*} FROM ${2:table_name} WHERE ${3:condition};",
            description: "SELECT statement"
        ),
        SnippetTemplate(
            label: "insert",
            insertText: "INSERT INTO ${1:table_name} (${2:column1, column2}) VALUES (${3:value1, value2});",
            description: "INSERT statement"
        ),
        SnippetTemplate(
            label: "update",
            insertText: "UPDATE ${1:table_name} SET ${2:column} = ${3:value} WHERE ${4:condition};",
            description: "UPDATE statement"
        ),
        SnippetTemplate(
            label: "delete",
            insertText: "DELETE FROM ${1:table_name} WHERE ${2:condition};",
            description: "DELETE statement"
        ),
        SnippetTemplate(
            label: "create-table",
            insertText: """
CREATE TABLE ${1:table_name} (
    ${2:id} ${3:INT} PRIMARY KEY AUTO_INCREMENT,
    ${4:column_name} ${5:VARCHAR(255)} NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
""",
            description: "CREATE TABLE statement"
        ),
        SnippetTemplate(
            label: "alter-table",
            insertText: "ALTER TABLE ${1:table_name} ${2:ADD|DROP|MODIFY} ${3:COLUMN} ${4:column_definition};",
            description: "ALTER TABLE statement"
        ),
        SnippetTemplate(
            label: "create-index",
            insertText: "CREATE ${1:UNIQUE} INDEX ${2:index_name} ON ${3:table_name} (${4:column_name});",
            description: "CREATE INDEX statement"
        ),
        SnippetTemplate(
            label: "join",
            insertText: """
SELECT ${1:t1.*, t2.*}
FROM ${2:table1} t1
${3:INNER} JOIN ${4:table2} t2 ON t1.${5:id} = t2.${6:table1_id}
WHERE ${7:condition};
""",
            description: "JOIN query"
        ),
        SnippetTemplate(
            label: "group-by",
            insertText: """
SELECT ${1:column}, ${2:COUNT(*)} as count
FROM ${3:table_name}
GROUP BY ${1:column}
HAVING ${4:count > 1}
ORDER BY count DESC;
""",
            description: "GROUP BY query"
        ),
        SnippetTemplate(
            label: "case",
            insertText: """
CASE
    WHEN ${1:condition1} THEN ${2:result1}
    WHEN ${3:condition2} THEN ${4:result2}
    ELSE ${5:default_result}
END
""",
            description: "CASE expression"
        ),
        SnippetTemplate(
            label: "transaction",
            insertText: """
BEGIN TRANSACTION;
${1:-- SQL statements}
COMMIT;
""",
            description: "Transaction block"
        ),
        SnippetTemplate(
            label: "procedure",
            insertText: """
CREATE PROCEDURE ${1:procedure_name} (${2:IN param1 INT})
BEGIN
    ${3:-- procedure body}
END;
""",
            description: "Stored procedure"
        ),
        SnippetTemplate(
            label: "function",
            insertText: """
CREATE FUNCTION ${1:function_name} (${2:param1 INT})
RETURNS ${3:INT}
BEGIN
    ${4:-- function body}
    RETURN ${5:result};
END;
""",
            description: "User-defined function"
        ),
        SnippetTemplate(
            label: "trigger",
            insertText: """
CREATE TRIGGER ${1:trigger_name}
${2:BEFORE|AFTER} ${3:INSERT|UPDATE|DELETE} ON ${4:table_name}
FOR EACH ROW
BEGIN
    ${5:-- trigger body}
END;
""",
            description: "Database trigger"
        ),
        SnippetTemplate(
            label: "with-cte",
            insertText: """
WITH ${1:cte_name} AS (
    SELECT ${2:*}
    FROM ${3:table_name}
    WHERE ${4:condition}
)
SELECT * FROM ${1:cte_name};
""",
            description: "Common Table Expression"
        )
    ]
    
    public init() {}
    
    // MARK: - CompletionProvider Implementation
    
    public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()
        
        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeContext(context)
        var items: [CompletionItemModel] = []
        
        // Add appropriate completions based on context
        switch analysisResult.type {
        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            
        case .function:
            items.append(contentsOf: createFunctionCompletions(filter: analysisResult.filter))
            
        case .table:
            items.append(contentsOf: createTableCompletions(filter: analysisResult.filter))
            
        case .column:
            items.append(contentsOf: createColumnCompletions(for: analysisResult.tableName, filter: analysisResult.filter))
            
        case .dataType:
            items.append(contentsOf: createDataTypeCompletions(filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createFunctionCompletions(filter: analysisResult.filter))
            if supportsSnippets {
                items.append(contentsOf: createSnippetCompletions(filter: analysisResult.filter))
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return CompletionResult(
            items: items,
            context: context,
            isIncomplete: false,
            processingTime: processingTime
        )
    }
    
    // MARK: - Context Analysis
    
    private func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let lineText = context.lineText.uppercased().trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition)).uppercased()
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: String(context.text.prefix(context.cursorPosition)))
        
        // Check for function context
        if beforeCursor.hasSuffix("(") || isInFunctionContext(beforeCursor) {
            return ContextAnalysisResult(type: .function, filter: filter)
        }
        
        // Check for table context (after FROM, JOIN, UPDATE, INSERT INTO, etc.)
        if isInTableContext(beforeCursor) {
            return ContextAnalysisResult(type: .table, filter: filter)
        }
        
        // Check for column context (after SELECT, WHERE, ORDER BY, etc.)
        if isInColumnContext(beforeCursor) {
            let tableName = extractTableName(from: beforeCursor)
            return ContextAnalysisResult(type: .column, filter: filter, tableName: tableName)
        }
        
        // Check for data type context (in CREATE TABLE or ALTER TABLE)
        if isInDataTypeContext(beforeCursor) {
            return ContextAnalysisResult(type: .dataType, filter: filter)
        }
        
        // Default to keyword context for SQL statements
        if lineText.isEmpty || startsNewStatement(lineText) {
            return ContextAnalysisResult(type: .keyword, filter: filter)
        }
        
        return ContextAnalysisResult(type: .general, filter: filter)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
        return components.last ?? ""
    }
    
    private func isInFunctionContext(_ text: String) -> Bool {
        // Check if we're inside parentheses
        var parenCount = 0
        for char in text {
            if char == "(" {
                parenCount += 1
            } else if char == ")" {
                parenCount -= 1
            }
        }
        return parenCount > 0
    }
    
    private func isInTableContext(_ text: String) -> Bool {
        let tableKeywords = ["FROM", "JOIN", "INTO", "UPDATE", "TABLE"]
        
        // Check if the last keyword before cursor is a table keyword
        for keyword in tableKeywords {
            if let range = text.range(of: " \(keyword) ", options: [.backwards, .caseInsensitive]) {
                let afterKeyword = String(text[range.upperBound...])
                // Check if there's no other major keyword after this
                let otherKeywords = ["WHERE", "SET", "VALUES", "ON", "GROUP", "ORDER", "HAVING"]
                let hasOtherKeyword = otherKeywords.contains { afterKeyword.contains(" \($0) ") }
                if !hasOtherKeyword {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func isInColumnContext(_ text: String) -> Bool {
        let columnKeywords = ["SELECT", "WHERE", "SET", "ORDER BY", "GROUP BY", "ON"]
        
        for keyword in columnKeywords {
            if text.contains(keyword) {
                // Make sure we're not in a subquery or after another major keyword
                return true
            }
        }
        
        return false
    }
    
    private func isInDataTypeContext(_ text: String) -> Bool {
        // Check if we're in a CREATE TABLE or ALTER TABLE context
        text.contains("CREATE TABLE") || text.contains("ALTER TABLE")
    }
    
    private func extractTableName(from text: String) -> String? {
        // Try to extract table name from FROM clause
        if let fromMatch = text.range(of: #"FROM\s+(\w+)"#, options: [.regularExpression, .caseInsensitive]) {
            let match = text[fromMatch]
            let components = match.components(separatedBy: .whitespaces)
            if components.count > 1 {
                return components[1].lowercased()
            }
        }
        
        return nil
    }
    
    private func startsNewStatement(_ text: String) -> Bool {
        let statementStarters = ["SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "WITH"]
        return statementStarters.contains { text.hasPrefix($0) }
    }
    
    // MARK: - Completion Creation Methods
    
    private func createKeywordCompletions(filter: String) -> [CompletionItemModel] {
        keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                let insertText: String
                
                // Add common patterns for certain keywords
                switch keyword {
                case "SELECT":
                    insertText = "SELECT $0"

                case "FROM":
                    insertText = "FROM $0"

                case "WHERE":
                    insertText = "WHERE $0"

                case "INSERT":
                    insertText = "INSERT INTO $0"

                case "CREATE TABLE":
                    insertText = "CREATE TABLE $0 ("

                case "PRIMARY KEY":
                    insertText = "PRIMARY KEY"

                case "FOREIGN KEY":
                    insertText = "FOREIGN KEY ($0) REFERENCES"

                default:
                    insertText = keyword
                }
                
                return CompletionItemModel(
                    label: keyword,
                    insertText: insertText,
                    kind: .keyword,
                    detail: "SQL keyword",
                    priority: 80,
                    preselect: keyword.uppercased() == filter.uppercased()
                )
            }
    }
    
    private func createFunctionCompletions(filter: String) -> [CompletionItemModel] {
        functions
            .filter { function in
                filter.isEmpty || function.localizedCaseInsensitiveContains(filter)
            }
            .map { function in
                CompletionItemModel(
                    label: function,
                    insertText: "\(function)($0)",
                    kind: .function,
                    detail: "SQL function",
                    priority: 75
                )
            }
    }
    
    private func createTableCompletions(filter: String) -> [CompletionItemModel] {
        commonTables
            .filter { table in
                filter.isEmpty || table.localizedCaseInsensitiveContains(filter)
            }
            .map { table in
                CompletionItemModel(
                    label: table,
                    insertText: table,
                    kind: .class,
                    detail: "Table name",
                    priority: 70
                )
            }
    }
    
    private func createColumnCompletions(for _: String?, filter: String) -> [CompletionItemModel] {
        // In a real implementation, this would query schema information
        // For now, return common column names
        commonColumns
            .filter { column in
                filter.isEmpty || column.localizedCaseInsensitiveContains(filter)
            }
            .map { column in
                CompletionItemModel(
                    label: column,
                    insertText: column,
                    kind: .field,
                    detail: "Column name",
                    priority: 70
                )
            }
    }
    
    private func createDataTypeCompletions(filter: String) -> [CompletionItemModel] {
        let dataTypes = [
            ("INT", "Integer"),
            ("BIGINT", "Big integer"),
            ("SMALLINT", "Small integer"),
            ("DECIMAL(p,s)", "Decimal number"),
            ("FLOAT", "Floating point"),
            ("DOUBLE", "Double precision"),
            ("VARCHAR(n)", "Variable character"),
            ("CHAR(n)", "Fixed character"),
            ("TEXT", "Text"),
            ("DATE", "Date"),
            ("TIME", "Time"),
            ("TIMESTAMP", "Timestamp"),
            ("DATETIME", "Date and time"),
            ("BOOLEAN", "Boolean"),
            ("JSON", "JSON data"),
            ("BLOB", "Binary large object")
        ]
        
        return dataTypes
            .filter { type, _ in
                filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
            }
            .map { type, description in
                CompletionItemModel(
                    label: type,
                    insertText: type.contains("(") ? type : type,
                    kind: .typeParameter,
                    detail: description,
                    priority: 75
                )
            }
    }
    
    private func createSnippetCompletions(filter: String) -> [CompletionItemModel] {
        snippets
            .filter { snippet in
                filter.isEmpty || snippet.label.localizedCaseInsensitiveContains(filter)
            }
            .map { snippet in
                CompletionItemModel(
                    label: snippet.label,
                    insertText: snippet.insertText,
                    kind: .snippet,
                    detail: snippet.description,
                    priority: 90,
                    snippetSupport: true
                )
            }
    }
}

// MARK: - Supporting Types

private struct ContextAnalysisResult {
    enum CompletionType {
        case keyword
        case function
        case table
        case column
        case dataType
        case general
    }
    
    let type: CompletionType
    let filter: String
    let tableName: String?
    
    init(type: CompletionType, filter: String, tableName: String? = nil) {
        self.type = type
        self.filter = filter
        self.tableName = tableName
    }
}

private struct SnippetTemplate {
    let label: String
    let insertText: String
    let description: String
}
