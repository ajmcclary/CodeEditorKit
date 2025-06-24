import XCTest
@testable import CodeEditorPlugin
import AppKit

@MainActor
final class ConfigurationTests: XCTestCase {
    
    // MARK: - STTextView Configuration Tests
    
    @MainActor
    func testSTTextViewDefaults() {
        let textView = STTextView()
        
        // Test default values
        XCTAssertNotNil(textView.font)
        XCTAssertNotNil(textView.textColor)
        XCTAssertNotNil(textView.backgroundColor)
        XCTAssertTrue(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertFalse(textView.showsLineNumbers)
        XCTAssertFalse(textView.highlightSelectedLine)
    }
    
    @MainActor
    func testSTTextViewConfigurationChanges() {
        let textView = STTextView()
        
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
        // Test that each token type has a color
        for tokenType in TokenType.allCases {
            let color = AdaptiveColorSystem.syntaxColor(for: tokenType)
            XCTAssertNotNil(color)
        }
    }
    
    // MARK: - Text Container Configuration Tests
    
    @MainActor
    func testTextContainerConfiguration() {
        let textView = STTextView()
        
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
        let textView = STTextView()
        textView.text = "Test content"
        
        // Create text range for annotation
        guard let textContentStorage = textView.textContentStorage else {
            XCTFail("Text content storage not available")
            return
        }
        
        guard let startLocation = textContentStorage.location(textContentStorage.documentRange.location, offsetBy: 0),
              let endLocation = textContentStorage.location(startLocation, offsetBy: 1),
              let textRange = NSTextRange(location: startLocation, end: endLocation) else {
            XCTFail("Could not create text range")
            return
        }
        
        let annotation = STAnnotation(id: "test", range: textRange, content: "Test annotation")
        
        textView.addAnnotation(annotation)
        
        // Verify annotation was added
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.id, "test")
    }
}

// Note: Plugin system has been removed and functionality integrated directly into STTextView