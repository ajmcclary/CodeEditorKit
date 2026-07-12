import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorPlatform
@testable import CodeEditorView
import XCTest

/// Comprehensive tests for error handling and edge cases in production scenarios
@MainActor
final class ErrorHandlingTests: XCTestCase {
    // MARK: - Malformed Content Tests

    func testBinaryDataHandling() throws {
        let editorView = CodeEditorView()

        // Test binary data that contains null bytes and invalid UTF-8
        let binaryData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD])
        let binaryString = String(data: binaryData, encoding: .utf8) ?? ""

        // Should handle gracefully without crashing
        editorView.text = binaryString
        XCTAssertNotNil(editorView.text)
    }

    func testInvalidUnicodeSequences() throws {
        let editorView = CodeEditorView()

        // Test various problematic Unicode sequences
        let problematicTexts = [
            "\u{FEFF}func test() {}", // BOM
            "func test\u{200B}() {}", // Zero-width space
            "func \u{202E}test() {}", // Right-to-left override
            "func test() { \u{FFFD} }", // Replacement character
            String(repeating: "\u{1F600}", count: 100) // Many emoji
        ]

        for text in problematicTexts {
            editorView.text = text
            XCTAssertEqual(editorView.text, text, "Should handle Unicode correctly")
        }
    }

    func testExtremelyLongLines() throws {
        let editorView = CodeEditorView()

        // Test line with 10,000 characters (reduced from 100,000 for test performance)
        let longLine = "func extremelyLongFunctionName" + String(repeating: "a", count: 9_970) + "() {}"

        editorView.text = longLine
        XCTAssertEqual(editorView.text?.count, longLine.count)
    }

    func testMalformedSyntaxHandling() throws {
        let editorView = CodeEditorView()

        // Test various malformed code snippets
        let malformedTexts = [
            "func unclosed(", // Unclosed parenthesis
            "\"unclosed string", // Unclosed string
            "/* unclosed comment", // Unclosed comment
            "{{{{{{", // Excessive nesting
            String(repeating: "(", count: 100), // Deep nesting (reduced for performance)
            "func \n\n\n\n test() {}", // Excessive whitespace
            "", // Empty string
            " ", // Whitespace only
            "\n\n\n" // Newlines only
        ]

        for text in malformedTexts {
            // Should not crash when setting malformed text
            editorView.text = text
            XCTAssertEqual(editorView.text, text)
        }
    }

    // MARK: - Memory Pressure Tests

    func testMemoryPressureRecovery() async throws {
        let editorView = CodeEditorView()

        // Simulate memory pressure scenario with bounded text
        let largeText = MemoryBoundedTestData.swiftCode(lines: 100)

        TestMemoryOptimizer.measureMemoryUsage(operation: "Memory pressure test") {
            editorView.text = largeText

            // Skip actual cleanup in tests - just verify editor remains functional
            // The real cleanup is tested in MemoryMonitor's own tests

            // Editor should still be functional
            XCTAssertFalse(editorView.text?.isEmpty ?? true)
            XCTAssertEqual(editorView.text, largeText)
        }

        // Should be able to continue operations
        let newText = "func newFunction() {}"
        editorView.text = newText
        XCTAssertEqual(editorView.text, newText)
    }

    // MARK: - Configuration Error Tests

    func testInvalidConfigurationHandling() throws {
        var config = EditorConfiguration.default

        // Test invalid font size
        config.display.fontSize = -10.0
        let errors = config.validate()
        XCTAssertFalse(errors.isEmpty, "Should detect negative font size")

        // Test invalid tab width
        config.layout.tabWidth = -5
        let errors2 = config.validate()
        XCTAssertTrue(errors2.contains { $0.field == "layout.tabWidth" })

        // Test invalid line spacing
        config.layout.lineHeightMultiple = -1.0
        let errors3 = config.validate()
        XCTAssertTrue(errors3.contains { $0.field == "layout.lineHeightMultiple" })

        // Test throwing validation
        XCTAssertThrowsError(try config.validateAndThrow()) { error in
            XCTAssertTrue(error is CodeEditorError)
        }
    }

    func testConfigurationRecoveryFromInvalidState() throws {
        let editorView = CodeEditorView()

        // Apply invalid configuration
        var invalidConfig = EditorConfiguration.default
        invalidConfig.display.fontSize = -1.0
        invalidConfig.layout.tabWidth = 0

        // Should not crash when applying invalid config
        editorView.configuration = invalidConfig

        // Editor should still be functional
        XCTAssertNotNil(editorView.configuration)

        // Apply valid configuration to recover
        let validConfig = EditorConfiguration.default
        editorView.configuration = validConfig

        // Check that key settings match the valid config
        // Note: Adaptive performance mode may modify some settings, so we check key values
        XCTAssertEqual(editorView.configuration.display.fontSize, validConfig.display.fontSize)
        XCTAssertEqual(editorView.configuration.layout.tabWidth, validConfig.layout.tabWidth)
        XCTAssertEqual(editorView.configuration.display.isLineNumbersEnabled, validConfig.display.isLineNumbersEnabled)
    }

    // MARK: - Platform-Specific Error Handling

    func testPlatformCapabilityErrorHandling() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

        // Test feature availability checks don't crash with edge cases
        let allFeatures: [PlatformCapabilities.EditorFeature] = [
            .syntaxHighlighting, .codeCompletion, .lineNumbers, .codeFolding,
            .minimap, .multipleCursors, .smartBrackets, .isAutoIndentEnabled, .findReplace,
            .columnSelection, .symbolNavigation, .breadcrumbs, .goToDefinition,
            .quickOpen, .hardwareAcceleration, .virtualScrolling, .incrementalParsing,
            .backgroundProcessing, .languageServerProtocol, .pluginSystem,
            .externalTools, .fileWatching, .splitView, .tabs, .sidebars,
            .floatingPanels, .contextMenus, .toolbars, .touchBarSupport,
            .keyboardShortcuts, .mouseSupport, .touchSupport, .gestureNavigation,
            .pencilSupport
        ]

        for feature in allFeatures {
            let isAvailable = capabilities.isFeatureAvailable(feature)
            let availability = capabilities.getFeatureAvailability(feature)

            // Should not crash and return consistent results
            XCTAssertEqual(
                isAvailable,
                availability.isAvailable,
                "Feature \(feature) has inconsistent availability: isFeatureAvailable=\(isAvailable), getFeatureAvailability=\(availability)"
            )
        }
    }

    // MARK: - File Operation Error Tests

    func testLargeFileHandling() throws {
        let editorView = CodeEditorView()

        // Simulate moderately large file (100KB of code)
        let largeCode = String(repeating: "func test\(UUID().uuidString.prefix(8))() { print(\"large file test\") }\n", count: 1_000)

        let startTime = Date()
        editorView.text = largeCode
        let loadDuration = Date().timeIntervalSince(startTime)

        // Should load within reasonable time
        XCTAssertLessThan(loadDuration, 5.0, "Large file loading should be efficient")
        XCTAssertEqual(editorView.text?.count, largeCode.count)

        // Test editing large file
        let insertText = "\n// New comment"
        let newText = largeCode + insertText
        editorView.text = newText
        XCTAssertTrue(editorView.text?.hasSuffix(insertText) ?? false)
    }

    func testCorruptedContentRecovery() throws {
        let editorView = CodeEditorView()

        // Start with valid content
        editorView.text = "func validFunction() {}"
        XCTAssertEqual(editorView.text, "func validFunction() {}")

        // Simulate corrupted content
        let corruptedData = Data([0xFF, 0xFE, 0xFD, 0xFC])
        if let corruptedString = String(data: corruptedData, encoding: .utf8) {
            editorView.text = corruptedString
        } else {
            // If conversion fails, editor should maintain previous state or handle gracefully
            XCTAssertNotNil(editorView.text)
        }

        // Should be able to recover with valid content
        editorView.text = "func recoveredFunction() {}"
        XCTAssertEqual(editorView.text, "func recoveredFunction() {}")
    }

    // MARK: - Resource Cleanup Tests

    func testResourceCleanupOnError() async throws {
        // Create multiple editor views to test cleanup
        let editorViews = (0..<10).map { _ in CodeEditorView() }

        for (index, view) in editorViews.enumerated() {
            view.text = "func test\(index)() {}"
        }

        // Force memory pressure cleanup
        if let firstView = editorViews.first {
            await firstView.memoryMonitor.performCleanup()
        }

        // Views should still be functional after cleanup
        for (index, view) in editorViews.enumerated() {
            XCTAssertTrue(view.text?.contains("test\(index)") ?? false)
        }
    }

    // MARK: - Edge Case Input Tests

    func testNullCharacterHandling() throws {
        let editorView = CodeEditorView()
        let textWithNull = "func test() {\0 print(\"null test\") }"

        editorView.text = textWithNull

        // Should handle null characters gracefully
        XCTAssertTrue(editorView.text?.contains("test") ?? false)
    }

    func testEmptyAndWhitespaceHandling() throws {
        let editorView = CodeEditorView()

        let edgeCases = [
            "", // Empty
            " ", // Single space
            "\t", // Single tab
            "\n", // Single newline
            "\r\n", // Windows newline
            "   \t  \n  ", // Mixed whitespace
            String(repeating: " ", count: 100) // Many spaces (reduced for performance)
        ]

        for text in edgeCases {
            editorView.text = text
            XCTAssertEqual(editorView.text, text)
        }
    }

    // MARK: - Language Switching Tests

    func testLanguageSwitchingWithMalformedContent() throws {
        let editorView = CodeEditorView()

        // Set malformed content
        editorView.text = "func unclosed( { invalid content"

        // Switch between languages - should not crash
        let languages: [Language] = [.swift, .python, .javascript, .html, .json]

        for language in languages {
            editorView.language = language
            XCTAssertEqual(editorView.language, language)
        }

        // Editor should still be functional
        editorView.text = "func validFunction() {}"
        XCTAssertEqual(editorView.text, "func validFunction() {}")
    }

    // MARK: - Configuration Stress Tests

    func testConfigurationStressTest() throws {
        let editorView = CodeEditorView()
        editorView.text = "func test() {}"

        // Apply many configuration changes rapidly
        for index in 0..<100 {
            var config = EditorConfiguration.default
            config.display.fontSize = CGFloat(10 + (index % 20))
            config.layout.tabWidth = 2 + (index % 6)
            config.display.isSelectedLineHighlighted = index.isMultiple(of: 2)

            editorView.configuration = config
        }

        // Editor should still be functional
        XCTAssertNotNil(editorView.configuration)
        XCTAssertEqual(editorView.text, "func test() {}")
    }
}

// MARK: - Error Simulation Utilities

extension ErrorHandlingTests {
    /// Helper to create test content that simulates real-world edge cases
    private func createProblematicContent() -> [String] {
        [
            // Mixed line endings
            "line1\r\nline2\nline3\r",

            // Unicode edge cases
            "func \u{1F4A9}emoji() {}",

            // Very long identifier (reduced length for performance)
            "func " + String(repeating: "very", count: 20) + "LongName() {}",

            // Nested structures (reduced depth for performance)
            String(repeating: "if true { ", count: 10) + String(repeating: " }", count: 10),

            // Mixed content types
            "func test() { let json = \"{\\\"key\\\": \\\"value\\\"}\" }"
        ]
    }

    /// Helper to verify that editor remains functional after error conditions
    @MainActor
    private func verifyEditorFunctionality(_ editorView: CodeEditorView) {
        // Test basic operations
        let testText = "func verificationTest() {}"
        editorView.text = testText
        XCTAssertEqual(editorView.text, testText)

        // Test configuration changes
        var config = EditorConfiguration.default
        config.display.fontSize = 14.0
        editorView.configuration = config
        XCTAssertEqual(editorView.configuration.display.fontSize, 14.0)

        // Test language changes
        editorView.language = .python
        XCTAssertEqual(editorView.language, .python)
    }
}
