#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest

final class SyntaxHighlightingTests: XCTestCase {
    // MARK: - Language Detection Tests

    @MainActor
    func testLanguageDetection() {
        let highlighter = SyntaxHighlightingCoordinator()
        XCTAssertEqual(highlighter.detectLanguage(from: "swift"), .swift)
        // Other languages are now direct enum cases
        let jsLang = highlighter.detectLanguage(from: "js")
        XCTAssertNotEqual(jsLang, .plainText, "JavaScript should be supported")

        let pyLang = highlighter.detectLanguage(from: "py")
        XCTAssertNotEqual(pyLang, .plainText, "Python should be supported")

        XCTAssertEqual(highlighter.detectLanguage(from: "unknown"), .plainText)
    }

    // MARK: - Token Type Tests

    @MainActor
    func testTokenTypes() {
        // Test the unified TokenType from SyntaxHighlightingCoordinator
        let allTypes: [TokenType] = [
            .keyword, .string, .comment, .number, .function,
            .identifier, .type, .property, .punctuation, .operator
        ]

        // Ensure all token types are unique
        XCTAssertEqual(Set(allTypes).count, allTypes.count)
    }

    // MARK: - Swift Highlighting Tests

    @MainActor
    func testSwiftKeywordHighlighting() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = "func test() { let x = 10; var y = 20 }"
        let tokens = highlighter.highlight(source: code, language: .swift)

        // Check for keyword tokens
        let keywordTokens = tokens.filter { $0.type == .keyword }
        XCTAssertFalse(keywordTokens.isEmpty, "Should detect Swift keywords")

        // Verify specific keywords are found
        let funcToken = keywordTokens.first {
            guard let range = Range($0.range, in: code) else { return false }
            return String(code[range]).trimmingCharacters(in: .whitespaces) == "func"
        }
        XCTAssertNotNil(funcToken, "Should detect 'func' keyword")

        let letToken = keywordTokens.first {
            guard let range = Range($0.range, in: code) else { return false }
            return String(code[range]).trimmingCharacters(in: .whitespaces) == "let"
        }
        XCTAssertNotNil(letToken, "Should detect 'let' keyword")
    }

    @MainActor
    func testSwiftStringHighlighting() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = #"let message = "Hello, World!""#
        let tokens = highlighter.highlight(source: code, language: .swift)

        let stringTokens = tokens.filter { $0.type == .string }
        XCTAssertFalse(stringTokens.isEmpty, "Should detect strings")
    }

    @MainActor
    func testSwiftNumberHighlighting() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = "let x = 42; let y = 3.14159"
        let tokens = highlighter.highlight(source: code, language: .swift)

        let numberTokens = tokens.filter { $0.type == .number }
        XCTAssertGreaterThanOrEqual(numberTokens.count, 2, "Should detect numbers")
    }

    @MainActor
    func testSwiftCommentHighlighting() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = """
        // This is a comment
        let x = 10
        /* Multi-line
        comment */
        """
        let tokens = highlighter.highlight(source: code, language: .swift)

        let commentTokens = tokens.filter { $0.type == .comment }
        XCTAssertGreaterThanOrEqual(commentTokens.count, 1, "Should detect comments")
    }

    // MARK: - JavaScript Highlighting Tests

    @MainActor
    func testJavaScriptHighlighting() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = """
        function greet(name) {
            const message = `Hello, ${name}!`;
            return message;
        }
        """
        // Get the JavaScript language definition
        let jsLang = highlighter.detectLanguage(from: "js")
        let tokens = highlighter.highlight(source: code, language: jsLang)

        // Check for various token types
        let keywordTokens = tokens.filter { $0.type == .keyword }
        let stringTokens = tokens.filter { $0.type == .string }
        _ = tokens.filter { $0.type == .function }

        XCTAssertFalse(keywordTokens.isEmpty, "Should detect JS keywords")
        XCTAssertFalse(stringTokens.isEmpty, "Should detect JS strings")

        // Verify specific patterns
        let functionKeyword = keywordTokens.first {
            guard let range = Range($0.range, in: code) else { return false }
            return String(code[range]) == "function"
        }
        XCTAssertNotNil(functionKeyword, "Should detect 'function' keyword")
    }

    // MARK: - Python Highlighting Tests

    @MainActor
    func testPythonHighlighting() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = """
        def factorial(n):
            # Calculate factorial
            if n <= 1:
                return 1
            return n * factorial(n - 1)
        """
        // Get the Python language definition
        let pyLang = highlighter.detectLanguage(from: "py")
        let tokens = highlighter.highlight(source: code, language: pyLang)

        let keywordTokens = tokens.filter { $0.type == .keyword }
        let commentTokens = tokens.filter { $0.type == .comment }
        let numberTokens = tokens.filter { $0.type == .number }

        XCTAssertFalse(keywordTokens.isEmpty, "Should detect Python keywords")
        XCTAssertFalse(commentTokens.isEmpty, "Should detect Python comments")
        XCTAssertFalse(numberTokens.isEmpty, "Should detect Python numbers")
    }

    // MARK: - HTML Highlighting Tests

    @MainActor
    func testHTMLHighlighting() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = """
        <div class="container">
            <h1>Hello World</h1>
            <p id="message">Welcome!</p>
        </div>
        """
        // Get the HTML language definition
        let htmlLang = highlighter.detectLanguage(from: "html")
        let tokens = highlighter.highlight(source: code, language: htmlLang)

        // HTML should have keywords for tags and strings for attributes
        let keywordTokens = tokens.filter { $0.type == .keyword }
        let stringTokens = tokens.filter { $0.type == .string }

        XCTAssertFalse(keywordTokens.isEmpty, "Should detect HTML tags")
        XCTAssertFalse(stringTokens.isEmpty, "Should detect HTML attribute values")
    }

    // MARK: - JSON Highlighting Tests

    @MainActor
    func testJSONHighlighting() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = """
        {
            "name": "John Doe",
            "age": 30,
            "active": true,
            "values": [1, 2, 3]
        }
        """
        // Get the JSON language definition
        let jsonLang = highlighter.detectLanguage(from: "json")
        let tokens = highlighter.highlight(source: code, language: jsonLang)

        let stringTokens = tokens.filter { $0.type == .string }
        let numberTokens = tokens.filter { $0.type == .number }
        let keywordTokens = tokens.filter { $0.type == .keyword }

        XCTAssertFalse(stringTokens.isEmpty, "Should detect JSON strings")
        XCTAssertFalse(numberTokens.isEmpty, "Should detect JSON numbers")
        XCTAssertFalse(keywordTokens.isEmpty, "Should detect JSON keywords (true, false, null)")
        // Note: JSON highlighting may not classify braces/brackets as punctuation tokens
        XCTAssertFalse(tokens.isEmpty, "Should detect tokens in JSON code")
    }

    // MARK: - Performance Tests

    @MainActor
    func testHighlightingPerformance() {
        let highlighter = SyntaxHighlightingCoordinator()
        let largeCode = String(repeating: """
        func processData(_ data: [String]) -> [String: Int] {
            var result: [String: Int] = [:]
            for item in data {
                if let existingCount = result[item] {
                    result[item] = existingCount + 1
                } else {
                    result[item] = 1
                }
            }
            return result
        }

        """, count: 100)

        measure {
            _ = highlighter.highlight(source: largeCode, language: .swift)
        }
    }

    // MARK: - Token Range Tests

    @MainActor
    func testTokenRangesValidity() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = "let x = 10; var y = 20"
        let tokens = highlighter.highlight(source: code, language: .swift)

        for token in tokens {
            // Ensure range is within bounds
            XCTAssertGreaterThanOrEqual(token.range.location, 0)
            XCTAssertLessThanOrEqual(token.range.location + token.range.length, code.count)

            // Ensure range is not empty
            XCTAssertGreaterThan(token.range.length, 0)
        }
    }

    @MainActor
    func testTokenRangesNoOverlap() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = "func test() { return 42 }"
        let tokens = highlighter.highlight(source: code, language: .swift)

        // Sort tokens by location
        let sortedTokens = tokens.sorted { $0.range.location < $1.range.location }

        // Check for overlaps
        for index in 0 ..< sortedTokens.count - 1 {
            let currentEnd = sortedTokens[index].range.location + sortedTokens[index].range.length
            let nextStart = sortedTokens[index + 1].range.location

            XCTAssertLessThanOrEqual(currentEnd, nextStart, "Tokens should not overlap")
        }
    }
    
    // MARK: - Language Enum Direct Mapping Tests
    
    @MainActor
    func testRegexHighlighterLanguageEnumMapping() {
        let regexHighlighter = RegexSyntaxHighlighter()
        
        // Test that all supported languages can be accessed directly via Language enum
        let supportedLanguages: [Language] = [
            .javascript, .typescript, .python, .go, .rust, .c, .cpp, .java,
            .html, .css, .json, .markdown, .yaml, .xml, .sql, .ruby, .php, .shell
        ]
        
        for language in supportedLanguages {
            let definition = regexHighlighter.languageDefinition(for: language)
            XCTAssertNotNil(definition, "Should find definition for \(language)")
            
            if let definition {
                XCTAssertFalse(definition.rules.isEmpty, "\(language) should have highlighting rules")
                XCTAssertEqual(definition.name, language.name, "Definition name should match language name")
                
                // Verify that the file extensions match
                let definitionExtensions = Set(definition.fileExtensions)
                let languageExtensions = Set(language.fileExtensions)
                XCTAssertEqual(
                    definitionExtensions,
                    languageExtensions,
                    "File extensions should match for \(language)"
                )
            }
        }
        
        // Test that Swift and plainText return nil (Swift uses SwiftSyntaxHighlighter, plainText has no highlighting)
        XCTAssertNil(
            regexHighlighter.languageDefinition(for: .swift),
            "Swift should not have regex definition (uses SwiftSyntaxHighlighter)"
        )
        XCTAssertNil(
            regexHighlighter.languageDefinition(for: .plainText),
            "Plain text should not have highlighting definition"
        )
    }
    
    @MainActor
    func testLanguageEnumMappingEfficiency() {
        let regexHighlighter = RegexSyntaxHighlighter()
        
        // Test that direct Language enum access is available and efficient
        let testCode = "function test() { return 'hello'; }"
        
        // Using new Language enum method
        if let jsDefinition = regexHighlighter.languageDefinition(for: .javascript) {
            let tokens = regexHighlighter.highlight(source: testCode, language: jsDefinition)
            XCTAssertFalse(tokens.isEmpty, "JavaScript highlighting should produce tokens")
            
            // Verify we get expected token types
            let hasKeywords = tokens.contains { $0.type == .keyword }
            let hasStrings = tokens.contains { $0.type == .string }
            XCTAssertTrue(hasKeywords, "Should detect JavaScript keywords")
            XCTAssertTrue(hasStrings, "Should detect JavaScript strings")
        } else {
            XCTFail("Should find JavaScript definition via Language enum")
        }
    }

    // MARK: - Cancellation Tests
    
    @MainActor
    func testApplyHighlightingCancellation() async throws {
        let coordinator = SyntaxHighlightingCoordinator()
        let largeCode = String(repeating: "let x = 10; var y = 20; ", count: 5_000)
        let tokens = coordinator.highlight(source: largeCode, language: .swift)
        
        // Create an attributed string
        let attributedString = NSMutableAttributedString(string: largeCode)
        
        // Create a task that will be cancelled
        let task = Task {
            try await coordinator.applyHighlighting(
                to: attributedString,
                tokens: tokens,
                progressHandler: nil
            )
        }
        
        // Cancel the task immediately
        task.cancel()
        
        // Verify that the task throws a cancellation error
        do {
            try await task.value
            XCTFail("Expected cancellation error")
        } catch {
            XCTAssertTrue(Task.isCancelled || error is CancellationError, "Should throw cancellation error")
        }
    }
    
    @MainActor
    func testApplyHighlightingProgressHandler() async throws {
        let coordinator = SyntaxHighlightingCoordinator()
        let code = String(repeating: "let x = 10; ", count: 200)
        let tokens = coordinator.highlight(source: code, language: .swift)
        
        // Create an attributed string
        let attributedString = NSMutableAttributedString(string: code)
        
        // Track progress updates
        var progressUpdates: [Double] = []
        
        // Apply highlighting with progress handler
        try await coordinator.applyHighlighting(
            to: attributedString,
            tokens: tokens
        ) { progress in
                progressUpdates.append(progress)
        }
        
        // Verify progress was reported
        XCTAssertFalse(progressUpdates.isEmpty, "Should report progress")
        XCTAssertEqual(progressUpdates.last, 1.0, "Final progress should be 1.0")
        
        // Verify highlighting was applied
        var hasHighlighting = false
        attributedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributedString.length)) { value, _, _ in
            if value != nil {
                hasHighlighting = true
            }
        }
        XCTAssertTrue(hasHighlighting, "Should have applied highlighting")
    }

    deinit {
        // Cleanup if needed
    }
}
