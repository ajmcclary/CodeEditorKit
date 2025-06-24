import XCTest
import AppKit
import SwiftUI
@testable import CodeEditorPlugin
@testable import CodeEditorSample

@MainActor
final class ComprehensiveViewTests: XCTestCase {
    
    // MARK: - STTextView Core Tests
    
    func testSTTextViewBasicProperties() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        
        // Test default properties
        XCTAssertTrue(textView.isEditable, "Should be editable by default")
        XCTAssertTrue(textView.isSelectable, "Should be selectable by default")
        XCTAssertFalse(textView.showsLineNumbers, "Line numbers should be off by default")
        XCTAssertFalse(textView.showsInvisibleCharacters, "Invisible characters should be off by default")
        XCTAssertFalse(textView.highlightSelectedLine, "Line highlighting should be off by default")
        
        // Test text manipulation
        textView.text = "Hello, World!"
        XCTAssertEqual(textView.text, "Hello, World!", "Text should be set correctly")
        
        // Test font
        let newFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.font = newFont
        XCTAssertEqual(textView.font, newFont, "Font should be updated")
    }
    
    func testSTTextViewLineNumbers() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        
        // Enable line numbers
        textView.showsLineNumbers = true
        textView.text = "Line 1\nLine 2\nLine 3"
        textView.layoutSubtreeIfNeeded()
        
        // Check gutter view exists
        XCTAssertNotNil(textView.gutterView, "Gutter view should exist when line numbers are enabled")
        
        // Check gutter view is visible
        if let gutterView = textView.gutterView {
            XCTAssertFalse(gutterView.isHidden, "Gutter view should be visible")
            XCTAssertGreaterThan(gutterView.frame.width, 0, "Gutter should have width")
        }
    }
    
    func testSTTextViewThemes() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        
        // Test different theme colors
        let themes = [
            (bg: NSColor.white, fg: NSColor.black, selected: NSColor.blue.withAlphaComponent(0.2)),
            (bg: NSColor(calibratedWhite: 0.1, alpha: 1.0), fg: NSColor.white, selected: NSColor.blue.withAlphaComponent(0.3))
        ]
        
        for theme in themes {
            textView.backgroundColor = theme.bg
            textView.textColor = theme.fg
            textView.selectedLineHighlightColor = theme.selected
            
            XCTAssertEqual(textView.backgroundColor, theme.bg, "Background color should be set")
            XCTAssertEqual(textView.textColor, theme.fg, "Text color should be set")
            XCTAssertEqual(textView.selectedLineHighlightColor, theme.selected, "Selected line color should be set")
        }
    }
    
    // MARK: - Content View Tests
    
    func testSTContentView() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let contentView = textView.textContentView
        
        XCTAssertNotNil(contentView, "Content view should exist")
        XCTAssertTrue(contentView.isFlipped, "Content view should be flipped")
        
        // Add text and check for layout fragments
        textView.text = "Test content"
        textView.layoutSubtreeIfNeeded()
        
        // Content view should contain text layout fragment views
        let fragmentViews = contentView.subviews.filter { $0 is STTextLayoutFragmentView }
        XCTAssertGreaterThan(fragmentViews.count, 0, "Should have text layout fragment views")
    }
    
    // MARK: - Gutter View Tests
    
    func testSTGutterView() async {
        let gutterView = STGutterView()
        
        XCTAssertTrue(gutterView.isFlipped, "Gutter view should be flipped")
        
        // Test with a text view
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.showsLineNumbers = true
        textView.text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        textView.layoutSubtreeIfNeeded()
        
        if let gutter = textView.gutterView {
            XCTAssertEqual(gutter.superview, textView, "Gutter should be a subview of text view")
            XCTAssertGreaterThan(gutter.frame.width, 0, "Gutter should have width")
            XCTAssertEqual(gutter.frame.height, textView.frame.height, "Gutter height should match text view")
        } else {
            XCTFail("Gutter view should exist when line numbers are enabled")
        }
    }
    
    // MARK: - Text Layout Fragment View Tests
    
    func testSTTextLayoutFragmentView() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Test line 1\nTest line 2"
        textView.layoutSubtreeIfNeeded()
        
        // Find fragment views
        let fragmentViews = textView.textContentView.subviews.compactMap { $0 as? STTextLayoutFragmentView }
        
        XCTAssertGreaterThan(fragmentViews.count, 0, "Should have fragment views for text")
        
        for fragmentView in fragmentViews {
            XCTAssertTrue(fragmentView.isFlipped, "Fragment views should be flipped")
            XCTAssertNotNil(fragmentView.layoutFragment, "Fragment view should have a layout fragment")
        }
    }
    
    // MARK: - Line Highlight View Tests
    
    func testSTLineHighlightView() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.highlightSelectedLine = true
        textView.text = "Line 1\nLine 2\nLine 3"
        textView.layoutSubtreeIfNeeded()
        
        // The line highlight view should exist
        let lineHighlightView = textView.lineHighlightView
        XCTAssertNotNil(lineHighlightView, "Line highlight view should exist")
        
        // Set selection and check highlight
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.updateSelectedLineHighlight()
    }
    
    // MARK: - Insertion Point View Tests
    
    func testSTInsertionPointView() async {
        let insertionPointView = STInsertionPointView()
        
        XCTAssertTrue(insertionPointView.isFlipped, "Insertion point view should be flipped")
        
        // Test with text view
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Test"
        textView.layoutSubtreeIfNeeded()
        
        // Look for insertion point view
        let insertionPoints = findSubviews(of: textView.textContentView) { $0 is STInsertionPointView }
        XCTAssertGreaterThan(insertionPoints.count, 0, "Should have insertion point view when editable")
    }
    
    // MARK: - SwiftUI Integration Tests
    
    func testCodeEditorView() async {
        // Test different configurations
        let configurations = [
            EditorConfiguration.fullFeatured,
            EditorConfiguration.minimal,
            EditorConfiguration.markdown,
            EditorConfiguration.presentation
        ]
        
        for config in configurations {
            let binding = Binding<String>(
                get: { "Test code" },
                set: { _ in }
            )
            
            let editorView = CodeEditorView(
                configuration: config,
                text: binding,
                language: "swift"
            )
            
            // Create the NSView
            let coordinator = editorView.makeCoordinator()
            let nsView = editorView.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
            
            // Test that configuration is applied
            XCTAssertEqual(nsView.showsLineNumbers, config.showLineNumbers, "Line numbers should match config")
            XCTAssertEqual(nsView.isEditable, config.isEditable, "Editability should match config")
            XCTAssertEqual(nsView.showsInvisibleCharacters, config.showInvisibleCharacters, "Invisible chars should match config")
            XCTAssertEqual(nsView.highlightSelectedLine, config.highlightSelectedLine, "Line highlight should match config")
        }
    }
    
    // MARK: - Configuration Tests
    
    func testEditorConfigurations() async {
        // Test each preset configuration
        let presets: [ConfigurationPreset] = [.fullFeatured, .minimal, .readOnly, .markdown, .presentation]
        
        for preset in presets {
            let config = preset.configuration
            
            switch preset {
            case .fullFeatured:
                XCTAssertTrue(config.showLineNumbers, "Full featured should show line numbers")
                XCTAssertTrue(config.isEditable, "Full featured should be editable")
                XCTAssertTrue(config.highlightSelectedLine, "Full featured should highlight selected line")
                
            case .minimal:
                XCTAssertFalse(config.showLineNumbers, "Minimal should not show line numbers")
                XCTAssertTrue(config.isEditable, "Minimal should be editable")
                
            case .readOnly:
                XCTAssertFalse(config.isEditable, "Read only should not be editable")
                XCTAssertTrue(config.showLineNumbers, "Read only should show line numbers")
                
            case .markdown:
                XCTAssertTrue(config.wrapLines, "Markdown should wrap lines")
                XCTAssertTrue(config.isEditable, "Markdown should be editable")
                
            case .presentation:
                XCTAssertGreaterThan(config.fontSize, 16, "Presentation should have larger font")
                XCTAssertFalse(config.showLineNumbers, "Presentation should not show line numbers")
            }
        }
    }
    
    // MARK: - Theme Tests
    
    func testColorThemes() async {
        let themes: [ColorTheme] = ColorTheme.allCases
        
        for theme in themes {
            // Test that each theme has proper colors
            XCTAssertNotNil(theme.backgroundColor, "Theme should have background color")
            XCTAssertNotNil(theme.textColor, "Theme should have text color")
            XCTAssertNotNil(theme.selectedLineColor, "Theme should have selected line color")
            XCTAssertNotNil(theme.keywordColor, "Theme should have keyword color")
            XCTAssertNotNil(theme.stringColor, "Theme should have string color")
            XCTAssertNotNil(theme.commentColor, "Theme should have comment color")
            XCTAssertNotNil(theme.numberColor, "Theme should have number color")
            
            // Test contrast
            let bgLuminance = luminance(of: theme.backgroundColor)
            let textLuminance = luminance(of: theme.textColor)
            let contrast = max(bgLuminance, textLuminance) / min(bgLuminance, textLuminance)
            
            XCTAssertGreaterThan(contrast, 3.0, "Theme '\(theme.displayName)' should have sufficient contrast")
        }
    }
    
    // MARK: - Plugin System Tests
    
    func testCustomAnnotationPlugin() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let plugin = CustomAnnotationPlugin()
        
        textView.addPlugin(plugin)
        
        // Verify plugin is added
        XCTAssertEqual(textView.plugins.count, 1, "Should have one plugin")
    }
    
    // MARK: - Helper Methods
    
    private func findSubviews<T>(of view: NSView, matching predicate: (NSView) -> Bool) -> [NSView] {
        var results: [NSView] = []
        
        if predicate(view) {
            results.append(view)
        }
        
        for subview in view.subviews {
            results.append(contentsOf: findSubviews(of: subview, matching: predicate))
        }
        
        return results
    }
    
    private func luminance(of color: NSColor) -> CGFloat {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        let r = rgb.redComponent
        let g = rgb.greenComponent
        let b = rgb.blueComponent
        
        // Relative luminance formula
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}