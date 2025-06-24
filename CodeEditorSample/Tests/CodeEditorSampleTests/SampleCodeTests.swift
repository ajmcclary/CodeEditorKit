@testable import CodeEditorSample
import XCTest

final class SampleCodeTests: XCTestCase {
    // MARK: - Sample Code Enum Tests

    func testSampleCodeCases() {
        let allCases = SampleCode.allCases

        XCTAssertEqual(allCases.count, 11, "Should have 11 sample code types")

        // Verify all cases exist
        XCTAssertTrue(allCases.contains(.swift))
        XCTAssertTrue(allCases.contains(.javascript))
        XCTAssertTrue(allCases.contains(.typescript))
        XCTAssertTrue(allCases.contains(.python))
        XCTAssertTrue(allCases.contains(.go))
        XCTAssertTrue(allCases.contains(.rust))
        XCTAssertTrue(allCases.contains(.cpp))
        XCTAssertTrue(allCases.contains(.java))
        XCTAssertTrue(allCases.contains(.html))
        XCTAssertTrue(allCases.contains(.css))
        XCTAssertTrue(allCases.contains(.json))
    }

    func testSampleCodeProperties() {
        // Test each sample code type
        for sample in SampleCode.allCases {
            // Test display name
            XCTAssertFalse(sample.displayName.isEmpty, "\(sample) should have a display name")

            // Test file extension
            XCTAssertFalse(sample.fileExtension.isEmpty, "\(sample) should have a file extension")

            // Test icon
            XCTAssertFalse(sample.icon.isEmpty, "\(sample) should have an icon")

            // Test icon color
            XCTAssertNotNil(sample.iconColor, "\(sample) should have an icon color")
        }
    }

    func testFileExtensions() {
        // Test specific file extensions
        XCTAssertEqual(SampleCode.swift.fileExtension, "swift")
        XCTAssertEqual(SampleCode.javascript.fileExtension, "js")
        XCTAssertEqual(SampleCode.typescript.fileExtension, "ts")
        XCTAssertEqual(SampleCode.python.fileExtension, "py")
        XCTAssertEqual(SampleCode.go.fileExtension, "go")
        XCTAssertEqual(SampleCode.rust.fileExtension, "rs")
        XCTAssertEqual(SampleCode.cpp.fileExtension, "cpp")
        XCTAssertEqual(SampleCode.java.fileExtension, "java")
        XCTAssertEqual(SampleCode.html.fileExtension, "html")
        XCTAssertEqual(SampleCode.css.fileExtension, "css")
        XCTAssertEqual(SampleCode.json.fileExtension, "json")
    }

    // MARK: - Sample Code Provider Tests

    func testSampleCodeProvider() {
        // Test that each language returns non-empty code
        for sample in SampleCode.allCases {
            let code = SampleCodeProvider.getCode(for: sample)

            XCTAssertFalse(code.isEmpty, "\(sample) should provide non-empty sample code")
            XCTAssertGreaterThan(code.count, 10, "\(sample) should provide substantial sample code")
        }
    }

    func testSwiftSampleCode() {
        let code = SampleCodeProvider.getCode(for: .swift)

        // Verify Swift-specific content
        XCTAssertTrue(code.contains("import"), "Swift code should contain import statements")
        XCTAssertTrue(code.contains("func"), "Swift code should contain function declarations")
        XCTAssertTrue(code.contains("class") || code.contains("struct"), "Swift code should contain type declarations")
    }

    func testJavaScriptSampleCode() {
        let code = SampleCodeProvider.getCode(for: .javascript)

        // Verify JavaScript-specific content
        XCTAssertTrue(code.contains("function") || code.contains("=>"), "JavaScript code should contain functions")
        XCTAssertTrue(
            code.contains("const") || code.contains("let") || code.contains("var"),
            "JavaScript code should contain variable declarations"
        )
    }

    func testPythonSampleCode() {
        let code = SampleCodeProvider.getCode(for: .python)

        // Verify Python-specific content
        XCTAssertTrue(
            code.contains("def") || code.contains("class"),
            "Python code should contain function or class definitions"
        )
        XCTAssertTrue(code.contains("import") || code.contains("from"), "Python code should contain import statements")
    }

    func testHTMLSampleCode() {
        let code = SampleCodeProvider.getCode(for: .html)

        // Verify HTML-specific content
        XCTAssertTrue(code.contains("<") && code.contains(">"), "HTML code should contain tags")
        XCTAssertTrue(code.contains("html") || code.contains("HTML"), "HTML code should reference HTML")
    }

    func testCSSSampleCode() {
        let code = SampleCodeProvider.getCode(for: .css)

        // Verify CSS-specific content
        XCTAssertTrue(code.contains("{") && code.contains("}"), "CSS code should contain style blocks")
        XCTAssertTrue(code.contains(":") && code.contains(";"), "CSS code should contain property declarations")
    }

    func testJSONSampleCode() {
        let code = SampleCodeProvider.getCode(for: .json)

        // Verify JSON-specific content
        XCTAssertTrue(code.contains("{") || code.contains("["), "JSON code should contain objects or arrays")
        XCTAssertTrue(code.contains("\""), "JSON code should contain quoted strings")

        // Test if it's valid JSON
        let data = code.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data), "JSON sample should be valid JSON")
    }

    func testCodeComplexity() {
        // Verify each sample has reasonable complexity
        for sample in SampleCode.allCases {
            let code = SampleCodeProvider.getCode(for: sample)
            let lines = code.components(separatedBy: .newlines)

            XCTAssertGreaterThan(lines.count, 5, "\(sample) should have at least 5 lines")

            // Check for comments (most languages use // or # or <!-- -->)
            let hasComments = code.contains("//") || code.contains("#") || code.contains("/*") || code.contains("<!--")
            XCTAssertTrue(hasComments, "\(sample) should include comments for demonstration")
        }
    }

    func testCodeSyntaxHighlighting() {
        // Test that sample code contains various syntax elements for highlighting
        for sample in SampleCode.allCases {
            let code = SampleCodeProvider.getCode(for: sample)

            switch sample {
            case .swift,
                 .javascript,
                 .typescript,
                 .go,
                 .rust,
                 .cpp,
                 .java:
                // These languages should have strings
                XCTAssertTrue(code.contains("\"") || code.contains("'"), "\(sample) should contain string literals")

            case .python:
                // Python uses # for comments
                XCTAssertTrue(code.contains("#"), "Python should contain comments")

            case .html:
                // HTML should have tags and attributes
                XCTAssertTrue(code.contains("<") && code.contains(">"), "HTML should contain tags")

            case .css:
                // CSS should have selectors and properties
                XCTAssertTrue(code.contains("{") && code.contains("}"), "CSS should contain rule blocks")

            case .json:
                // JSON should be properly formatted
                XCTAssertTrue(code.contains("\""), "JSON should contain quoted keys")
            }
        }
    }
}
