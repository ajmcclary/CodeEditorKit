import CodeEditorDiagnostics
@testable import CodeEditorSwiftUI
#if canImport(AppKit)
import AppKit
import CodeEditorLanguages
import CodeEditorTextModel
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorSyntaxHighlighting
@testable import CodeEditorView
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

    /// Regression: the `addStrings` regex builder used `\\\\.` inside a Swift raw
    /// string, which NSRegex interpreted as "two literal backslashes + any char"
    /// rather than the intended escape sequence `\\.`. Result: string literals
    /// containing escaped inner quotes (`"hello \"world\""`) were tokenized as a
    /// single trailing `""` instead of one token spanning the full literal.
    @MainActor
    func testStringHighlightingPreservesEscapedQuotes() {
        let highlighter = SyntaxHighlightingCoordinator()
        let code = #"let s = "hello \"world\"""#
        let tokens = highlighter.highlight(source: code, language: .javascript)
        let stringTokens = tokens.filter { $0.type == .string }

        XCTAssertEqual(
            stringTokens.count,
            1,
            "Escaped inner quotes must not split the literal. Got: \(debugTokenSummary(stringTokens, in: code))"
        )

        let stringText = stringTokens.first.flatMap { tokenText($0, in: code) }
        XCTAssertEqual(
            stringText,
            #""hello \"world\"""#,
            "String token should span the full literal including escaped inner quotes"
        )
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

        measure(options: Self.standardMeasureOptions) {
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

        // Test that all supported languages can be accessed directly via Language enum.
        // .json is excluded — NEXT.md B.4: JSON opts out of the regex pipeline
        // (descriptor sets `usesRegexHighlighter: false`); routing goes through
        // FastJSONTokenizer in HighlightingStrategyExecutor.
        let supportedLanguages: [Language] = [
            .javascript, .typescript, .python, .go, .rust, .c, .cpp, .java,
            .html, .css, .markdown, .yaml, .xml, .sql, .ruby, .php, .shell
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

    // MARK: - RegexSyntaxHighlighter Regression Tests (Phase 1)

    /// Proves that RegexSyntaxHighlighter(customLanguage:) correctly stores the
    /// language definition and highlight(source:) uses it — the fix for the bug
    /// where the convenience init discarded its parameter and always produced
    /// zero tokens.
    @MainActor
    func testRegexHighlighterCustomLanguageProducesTokens() {
        let regexHighlighter = RegexSyntaxHighlighter()

        // .json is excluded — NEXT.md B.4: JSON opts out of the regex pipeline
        // (descriptor sets `usesRegexHighlighter: false`); routing goes through
        // FastJSONTokenizer in HighlightingStrategyExecutor.
        let languages: [(Language, String)] = [
            (.javascript, "const x = 42; let y = 'hello'; function foo() { return x + y; }"),
            (.python, "def foo():\n    x = 42\n    return x * 2\n"),
            (.go, "package main\n\nfunc main() {\n    x := 42\n    fmt.Println(x)\n}"),
            (.rust, "fn main() {\n    let x = 42;\n    println!(\"{}\", x);\n}"),
            (.sql, "SELECT * FROM users WHERE active = 1 ORDER BY name;"),
            (.shell, "#!/bin/bash\n\necho \"Hello, World!\"\nif [ -f file.txt ]; then\n    cat file.txt\nfi"),
            (.markdown, "# Hello\n\nThis is **bold** and *italic* text.\n\n```js\nconst x = 1;\n```"),
            (.css, ".container {\n    color: red;\n    font-size: 16px;\n}")
        ]

        for (language, source) in languages {
            guard let definition = regexHighlighter.languageDefinition(for: language) else {
                XCTFail("Should find regex definition for \(language.name)")
                continue
            }

            let highlighter = RegexSyntaxHighlighter(customLanguage: definition)
            let tokens = highlighter.highlight(source: source)

            XCTAssertFalse(
                tokens.isEmpty,
                "RegexSyntaxHighlighter should produce tokens for \(language.name). Got 0 tokens for source: \(source.prefix(40))..."
            )

            // Verify at least one meaningful token type is present
            // (not all languages use .keyword — e.g. CSS uses .property / .type)
            let meaningfulTokens = tokens.filter {
                $0.type == .keyword || $0.type == .type ||
                $0.type == .property || $0.type == .function ||
                $0.type == .string || $0.type == .number
            }
            XCTAssertFalse(
                meaningfulTokens.isEmpty,
                "Should detect at least one meaningful token in \(language.name)"
            )
        }
    }

    /// Proves that .dockerfile is recognized as its own language (not mapped to .shell).
    @MainActor
    func testDockerfileDetectedAsOwnLanguage() {
        let detectionService = LanguageDetectionService()
        let language = detectionService.detectLanguage(fromFilename: "Dockerfile")
        XCTAssertEqual(language, .dockerfile, "Dockerfile should map to .dockerfile, not .shell")
    }

    @MainActor
    func testLanguageRegistryRegistersAllDescriptorLanguages() {
        let registry = LanguageRegistry()

        for language in Language.allCases {
            XCTAssertNotNil(
                registry.provider(for: language.identifier),
                "LanguageRegistry should register \(language.name)"
            )
        }

        XCTAssertEqual(registry.provider(forFileExtension: "cs")?.identifier, Language.csharp.identifier)
        XCTAssertEqual(registry.provider(forFileExtension: "kt")?.identifier, Language.kotlin.identifier)
        XCTAssertEqual(registry.provider(forFileExtension: "dart")?.identifier, Language.dart.identifier)
        XCTAssertEqual(registry.provider(forFileExtension: "toml")?.identifier, Language.toml.identifier)
        XCTAssertEqual(registry.provider(forFileExtension: "lua")?.identifier, Language.lua.identifier)

        let csharpTokens = registry.provider(for: Language.csharp.identifier)?
            .createHighlighter()
            .highlight(source: "public class Program { static void Main() {} }")
        XCTAssertFalse(csharpTokens?.isEmpty ?? true, "Descriptor-backed registry providers should create real highlighters")
    }

    /// Proves that Dockerfile regex definition produces tokens.
    @MainActor
    func testDockerfileHighlightingProducesTokens() {
        let dockerfileSource = """
        FROM ubuntu:22.04 AS builder
        RUN apt-get update && apt-get install -y curl
        WORKDIR /app
        COPY . .
        ENV NODE_ENV=production
        EXPOSE 8080
        CMD ["node", "server.js"]
        """

        let regexHighlighter = RegexSyntaxHighlighter()
        guard let definition = regexHighlighter.languageDefinition(for: .dockerfile) else {
            XCTFail("Should find regex definition for Dockerfile")
            return
        }

        let highlighter = RegexSyntaxHighlighter(customLanguage: definition)
        let tokens = highlighter.highlight(source: dockerfileSource)

        XCTAssertFalse(tokens.isEmpty, "Dockerfile highlighting should produce tokens")

        let keywordTokens = tokens.filter { $0.type == .keyword }
        XCTAssertFalse(keywordTokens.isEmpty, "Should detect Dockerfile instruction keywords")

        // Verify specific instructions are highlighted
        let instructionTexts = keywordTokens.compactMap { token -> String? in
            guard let range = Range(token.range, in: dockerfileSource) else { return nil }
            return String(dockerfileSource[range])
        }
        XCTAssertTrue(instructionTexts.contains("FROM"), "Should highlight FROM")
        XCTAssertTrue(instructionTexts.contains("RUN"), "Should highlight RUN")
        XCTAssertTrue(instructionTexts.contains("ENV"), "Should highlight ENV")
    }

    @MainActor
    func testViewportSyntaxCoordinatorUsesUTF16VisibleRanges() {
        let source = "😀\nlet marker = 1"
        let visibleRange = NSRange(
            location: TextRangeUtilities.utf16Length(of: "😀\n"),
            length: TextRangeUtilities.utf16Length(of: "let marker = 1")
        )
        let coordinator = ViewportSyntaxCoordinator(
            memoryMonitor: MemoryMonitor(),
            viewportExpansionRatio: 1.0
        )

        let tokens = coordinator.highlightViewport(
            source: source,
            visibleRange: visibleRange,
            language: .swift
        )

        XCTAssertTrue(
            tokens.contains { token in
                token.type == .keyword &&
                    token.range.location == visibleRange.location &&
                    tokenText(token, in: source)?.trimmingCharacters(in: .whitespacesAndNewlines) == "let"
            },
            "Viewport highlighting should preserve UTF-16 token offsets after emoji. Tokens: \(debugTokenSummary(tokens, in: source))"
        )
    }

    @MainActor
    func testOptimizedSyntaxCoordinatorUsesUTF16ViewportRanges() async {
        let prefix = "😀\n"
        let targetLine = "let marker = 1"
        let source = prefix + targetLine + "\n" + String(repeating: "let filler = 0\n", count: 800)
        let visibleRange = NSRange(
            location: TextRangeUtilities.utf16Length(of: prefix),
            length: TextRangeUtilities.utf16Length(of: targetLine)
        )
        let coordinator = OptimizedSyntaxHighlightingCoordinator(
            memoryMonitor: MemoryMonitor(),
            configuration: .init(
                enableViewportOptimization: true,
                viewportPadding: 0,
                maxChunkSize: 5_000,
                enableIncrementalHighlighting: true,
                cacheWarmingEnabled: false,
                circuitBreakerThreshold: 1
            )
        )

        let tokens = await coordinator.highlight(
            text: source,
            language: .swift,
            visibleRange: visibleRange
        )

        XCTAssertTrue(
            tokens.contains { token in
                token.type == .keyword &&
                    token.range.location == visibleRange.location &&
                    tokenText(token, in: source)?.trimmingCharacters(in: .whitespacesAndNewlines) == "let"
            },
            "Optimized viewport highlighting should preserve UTF-16 token offsets after emoji. Tokens: \(debugTokenSummary(tokens, in: source))"
        )
    }

    private func tokenText(_ token: HighlightedToken, in source: String) -> String? {
        TextRangeUtilities.substring(inUTF16Range: token.range, from: source)
    }

    private func debugTokenSummary(_ tokens: [HighlightedToken], in source: String) -> String {
        tokens
            .prefix(8)
            .map { token in
                "\(token.type)@\(token.range.location):\(token.range.length)=\(tokenText(token, in: source) ?? "nil")"
            }
            .joined(separator: ", ")
    }

    deinit {
        // Cleanup if needed
    }
}
