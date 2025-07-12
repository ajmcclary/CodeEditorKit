@testable import CodeEditorPlugin
import XCTest

final class RegexHighlighterPerformanceTests: XCTestCase {
    private var highlighter = RegexSyntaxHighlighter()
    
    override func setUp() {
        super.setUp()
        highlighter = RegexSyntaxHighlighter()
    }
    
    override func tearDown() {
        // Reset highlighter
        highlighter = RegexSyntaxHighlighter()
        super.tearDown()
    }
    
    // MARK: - Pre-sorting Tests
    
    func testLanguageDefinitionPreSortsRules() throws {
        // Create a language definition with rules in random priority order
        let rules = [
            try RegexSyntaxHighlighter.HighlightRule(pattern: "rule1", tokenType: .keyword, priority: 5),
            try RegexSyntaxHighlighter.HighlightRule(pattern: "rule2", tokenType: .string, priority: 10),
            try RegexSyntaxHighlighter.HighlightRule(pattern: "rule3", tokenType: .comment, priority: 1),
            try RegexSyntaxHighlighter.HighlightRule(pattern: "rule4", tokenType: .number, priority: 7),
            try RegexSyntaxHighlighter.HighlightRule(pattern: "rule5", tokenType: .function, priority: 3)
        ]
        
        let langDef = RegexSyntaxHighlighter.LanguageDefinition(
            name: "TestLang",
            fileExtensions: ["test"],
            rules: rules
        )
        
        // Verify rules are sorted by priority (descending)
        for index in 0..<langDef.rules.count - 1 {
            XCTAssertGreaterThanOrEqual(
                langDef.rules[index].priority,
                langDef.rules[index + 1].priority,
                "Rules should be sorted by priority in descending order"
            )
        }
        
        // Verify the expected order
        XCTAssertEqual(langDef.rules[0].priority, 10) // string rule
        XCTAssertEqual(langDef.rules[1].priority, 7)  // number rule
        XCTAssertEqual(langDef.rules[2].priority, 5)  // keyword rule
        XCTAssertEqual(langDef.rules[3].priority, 3)  // function rule
        XCTAssertEqual(langDef.rules[4].priority, 1)  // comment rule
    }
    
    func testBuiltInLanguageDefinitionsHavePreSortedRules() {
        // Test several built-in language definitions
        let languagesToTest: [Language] = [.javascript, .python, .rust, .go]
        
        for language in languagesToTest {
            if let langDef = highlighter.languageDefinition(for: language) {
                // Verify rules are sorted by priority
                for index in 0..<langDef.rules.count - 1 {
                    XCTAssertGreaterThanOrEqual(
                        langDef.rules[index].priority,
                        langDef.rules[index + 1].priority,
                        "\(language.name) rules should be sorted by priority in descending order"
                    )
                }
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testHighlightingPerformanceWithPreSortedRules() {
        // Get JavaScript definition (which has pre-sorted rules)
        guard let jsLang = highlighter.languageDefinition(for: .javascript) else {
            XCTFail("JavaScript language definition not found")
            return
        }
        
        // Create a large JavaScript file
        let largeCode = generateLargeJavaScriptCode(lines: 1_000)
        
        measure {
            _ = highlighter.highlight(source: largeCode, language: jsLang)
        }
    }
    
    func testHighlightingPerformanceComparison() {
        // This test compares performance with a language that has many rules
        guard let jsLang = highlighter.languageDefinition(for: .javascript) else {
            XCTFail("JavaScript language definition not found")
            return
        }
        
        let testCode = """
        function processData(items) {
            const results = [];
            for (let i = 0; i < items.length; i++) {
                // Process each item
                const item = items[i];
                const processed = {
                    id: item.id,
                    name: item.name.toUpperCase(),
                    value: item.value * 2.5,
                    active: true
                };
                results.push(processed);
            }
            return results;
        }
        
        const data = [
            { id: 1, name: "test", value: 10 },
            { id: 2, name: "example", value: 20 }
        ];
        
        console.log(processData(data));
        """
        
        // Run multiple iterations to get stable measurements
        let iterations = 100
        
        measure {
            for _ in 0..<iterations {
                _ = highlighter.highlight(source: testCode, language: jsLang)
            }
        }
    }
    
    func testPrioritizedRuleMatching() {
        // Test that higher priority rules match first
        let testCode = "const test = 'const inside string';"
        
        guard let jsLang = highlighter.languageDefinition(for: .javascript) else {
            XCTFail("JavaScript language definition not found")
            return
        }
        
        let tokens = highlighter.highlight(source: testCode, language: jsLang)
        
        // Find the tokens for the two "const" occurrences
        let constTokens = tokens.filter { token in
            guard let range = Range(token.range, in: testCode) else { return false }
            return testCode[range] == "const"
        }
        
        // First "const" should be a keyword (higher priority)
        XCTAssertEqual(constTokens.first?.type, .keyword, "First 'const' should be highlighted as keyword")
        
        // The string token should encompass the second "const"
        let stringTokens = tokens.filter { $0.type == .string }
        XCTAssertFalse(stringTokens.isEmpty, "Should have string tokens")
        
        // Verify the string contains the second "const"
        if let stringToken = stringTokens.first,
           let stringRange = Range(stringToken.range, in: testCode) {
            let stringContent = String(testCode[stringRange])
            XCTAssertTrue(stringContent.contains("const inside string"), "String should contain the text with 'const'")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateLargeJavaScriptCode(lines: Int) -> String {
        var code = ""
        
        for index in 0..<lines {
            if index.isMultiple(of: 10) {
                code += "// Comment line \(index)\n"
            } else if index.isMultiple(of: 7) {
                code += "const variable\(index) = 'string value \(index)';\n"
            } else if index.isMultiple(of: 5) {
                code += "function func\(index)(param) { return param * \(index); }\n"
            } else if index.isMultiple(of: 3) {
                code += "let number\(index) = \(Double(index) * 3.14159);\n"
            } else {
                code += "console.log('Processing item', \(index));\n"
            }
        }
        
        return code
    }
}
