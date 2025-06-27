import AppKit
@testable import CodeEditorPlugin
import XCTest

@MainActor
final class ConfigurationTests: XCTestCase {
    // MARK: - CodeEditorView Configuration Tests

    @MainActor
    func testCodeEditorViewDefaults() {
        let textView = CodeEditorView()

        // Test default values
        XCTAssertNotNil(textView.font)
        XCTAssertNotNil(textView.textColor)
        XCTAssertNotNil(textView.backgroundColor)
        XCTAssertTrue(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertTrue(textView.showsLineNumbers)
        XCTAssertTrue(textView.highlightSelectedLine)
    }

    @MainActor
    func testCodeEditorViewConfigurationChanges() {
        let textView = CodeEditorView()

        // Test changing configuration
        textView.showsLineNumbers = true
        XCTAssertTrue(textView.showsLineNumbers)

        textView.highlightSelectedLine = true
        XCTAssertTrue(textView.highlightSelectedLine)

        textView.isEditable = false
        XCTAssertFalse(textView.isEditable)

        let customFont = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.font = customFont
        XCTAssertEqual(textView.font, customFont)

        let customColor = NSColor.systemBlue
        textView.textColor = customColor
        XCTAssertEqual(textView.textColor, customColor)
    }

    // MARK: - Syntax Highlighting Configuration Tests

    @MainActor
    func testSyntaxHighlightingLanguages() {
        let coordinator = SyntaxHighlightingCoordinator()

        // Test supported file extensions
        let supportedExtensions = coordinator.supportedFileExtensions
        XCTAssertTrue(supportedExtensions.contains("swift"))
        XCTAssertTrue(supportedExtensions.contains("js"))
        XCTAssertTrue(supportedExtensions.contains("py"))
        XCTAssertTrue(supportedExtensions.contains("html"))
        XCTAssertTrue(supportedExtensions.contains("css"))
        XCTAssertTrue(supportedExtensions.contains("json"))
    }

    @MainActor
    func testTokenTypeColors() {
        // Test that each token type has an adaptive color
        for tokenType in TokenType.allCases {
            let color = tokenType.adaptiveColor
            XCTAssertNotNil(color)
        }
    }

    // MARK: - Text Container Configuration Tests

    @MainActor
    func testTextContainerConfiguration() {
        let textView = CodeEditorView()

        // Test width tracking
        textView.widthTracksTextView = true
        XCTAssertTrue(textView.widthTracksTextView)
        XCTAssertTrue(textView.textContainer?.widthTracksTextView ?? false)

        // Test resizability
        textView.isHorizontallyResizable = false
        XCTAssertFalse(textView.isHorizontallyResizable)

        textView.isVerticallyResizable = false
        XCTAssertFalse(textView.isVerticallyResizable)
    }

    // MARK: - Annotation Configuration Tests

    @MainActor
    func testAnnotationAddition() {
        let textView = CodeEditorView()
        textView.text = "Test content"

        // Create mock NSTextRange for annotation
        let mockRange = NSTextRange(
            location: MockTextLocation(offset: 0),
            end: MockTextLocation(offset: textView.text?.count ?? 0)
        )!
        let annotation = Annotation(range: mockRange, content: "Test annotation", id: "test")

        textView.addAnnotation(annotation)

        // Verify annotation was added
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.id, "test")
    }

    deinit {
        // Cleanup if needed
    }
}

// Note: Plugin system has been removed and functionality integrated directly into CodeEditorView
