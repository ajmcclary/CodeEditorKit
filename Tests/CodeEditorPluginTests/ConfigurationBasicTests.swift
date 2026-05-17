import CodeEditorPlatform
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
@testable import CodeEditorSyntaxHighlighting
import XCTest

/// Basic configuration tests separated from ConfigurationTests due to test discovery issues
@MainActor
final class ConfigurationBasicTests: XCTestCase {
    // MARK: - CodeEditorView Configuration Tests

    func testCodeEditorViewDefaults() {
        let textView = CodeEditorView(frame: .zero)

        // Test default values
        XCTAssertNotNil(textView.font)
        XCTAssertNotNil(textView.textColor)
        XCTAssertNotNil(textView.backgroundColor)
        XCTAssertTrue(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertTrue(textView.isLineNumbersEnabled)
        XCTAssertTrue(textView.isSelectedLineHighlightEnabled)
    }

    func testCodeEditorViewConfigurationChanges() {
        let textView = CodeEditorView(frame: .zero)

        // Test changing configuration
        textView.isLineNumbersEnabled = true
        XCTAssertTrue(textView.isLineNumbersEnabled)

        textView.isSelectedLineHighlightEnabled = true
        XCTAssertTrue(textView.isSelectedLineHighlightEnabled)

        textView.isEditable = false
        XCTAssertFalse(textView.isEditable)

        let customFont = PlatformFonts.monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.font = customFont
        XCTAssertEqual(textView.font, customFont)

        let customColor = PlatformColors.systemBlue
        textView.textColor = customColor
        XCTAssertEqual(textView.textColor, customColor)
    }

    // MARK: - Syntax Highlighting Configuration Tests

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

    func testTokenTypeColors() {
        // Test that each token type has an adaptive color
        for tokenType in TokenType.allCases {
            let color = tokenType.adaptiveColor
            XCTAssertNotNil(color)
        }
    }

    // MARK: - Text Container Configuration Tests

    func testTextContainerConfiguration() {
        let textView = CodeEditorView(frame: .zero)

        // Test width tracking
        #if canImport(AppKit)
        textView.textContainer?.widthTracksTextView = true
        XCTAssertTrue(textView.textContainer?.widthTracksTextView ?? false)
        #else
        textView.textContainer.widthTracksTextView = true
        XCTAssertTrue(textView.textContainer.widthTracksTextView)
        #endif

        // Test resizability
        #if canImport(AppKit)
        textView.isHorizontallyResizable = false
        XCTAssertFalse(textView.isHorizontallyResizable)

        textView.isVerticallyResizable = false
        XCTAssertFalse(textView.isVerticallyResizable)
        #endif
    }

    // MARK: - Annotation Configuration Tests

    func testAnnotationAddition() {
        let textView = CodeEditorView(frame: .zero)
        textView.text = "Test content"

        // Create mock NSTextRange for annotation
        guard let mockRange = NSTextRange(
            location: MockTextLocation(offset: 0),
            end: MockTextLocation(offset: textView.text?.count ?? 0)
        ) else {
            XCTFail("Failed to create mock range")
            return
        }
        let annotation = Annotation(range: mockRange, content: "Test annotation", id: "test")

        textView.addAnnotation(annotation)

        // Verify annotation was added
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.id, "test")
    }
}
