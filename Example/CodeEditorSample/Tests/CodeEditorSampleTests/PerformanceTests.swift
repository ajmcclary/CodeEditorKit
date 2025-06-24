import XCTest
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample

@MainActor
final class PerformanceTests: XCTestCase {
    
    // MARK: - Text Loading Performance
    
    func testLargeTextLoadingPerformance() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        
        // Generate large text (1000 lines)
        let lines = (1...1000).map { "Line \($0): This is a test line with some content to make it realistic." }
        let largeText = lines.joined(separator: "\n")
        
        measure {
            textView.text = largeText
            textView.layoutSubtreeIfNeeded()
        }
    }
    
    func testVeryLargeTextLoadingPerformance() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        
        // Generate very large text (10,000 lines)
        let lines = (1...10000).map { "Line \($0): This is a test line with some content to make it realistic." }
        let veryLargeText = lines.joined(separator: "\n")
        
        measure {
            textView.text = veryLargeText
            textView.layoutSubtreeIfNeeded()
        }
    }
    
    // MARK: - Scrolling Performance
    
    func testScrollingPerformance() async {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let textView = STTextView(frame: scrollView.bounds)
        
        scrollView.documentView = textView
        
        // Load large content
        let lines = (1...5000).map { "Line \($0): This is a test line for scrolling performance testing." }
        textView.text = lines.joined(separator: "\n")
        textView.layoutSubtreeIfNeeded()
        
        measure {
            // Simulate scrolling through the document
            for i in stride(from: 0, to: 5000, by: 100) {
                let point = CGPoint(x: 0, y: CGFloat(i * 16)) // Approximate line height
                scrollView.contentView.scroll(to: point)
                textView.layoutSubtreeIfNeeded()
            }
        }
    }
    
    // MARK: - Line Numbers Performance
    
    func testLineNumbersPerformance() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        textView.showsLineNumbers = true
        
        // Generate text with many lines
        let lines = (1...2000).map { "Line \($0): Code with line numbers" }
        let text = lines.joined(separator: "\n")
        
        measure {
            textView.text = text
            textView.layoutSubtreeIfNeeded()
        }
    }
    
    // MARK: - Text Editing Performance
    
    func testTypingPerformance() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        textView.text = "Initial text\n"
        
        measure {
            // Simulate typing 100 characters
            for i in 1...100 {
                textView.insertText("a", replacementRange: NSRange(location: NSNotFound, length: 0))
                if i % 10 == 0 {
                    textView.insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0))
                }
            }
        }
    }
    
    func testBulkEditingPerformance() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        
        // Start with medium-sized document
        let lines = (1...500).map { "Line \($0): Original content" }
        textView.text = lines.joined(separator: "\n")
        
        measure {
            // Replace all occurrences of "Original" with "Modified"
            if let text = textView.text {
                let modifiedText = text.replacingOccurrences(of: "Original", with: "Modified")
                textView.text = modifiedText
                textView.layoutSubtreeIfNeeded()
            }
        }
    }
    
    // MARK: - Theme Switching Performance
    
    func testThemeSwitchingPerformance() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        
        // Load sample code
        textView.text = SampleCodeProvider.getCode(for: .swift)
        
        let themes = ColorTheme.allCases
        
        measure {
            // Switch through all themes
            for theme in themes {
                textView.backgroundColor = theme.backgroundColor
                textView.textColor = theme.textColor
                textView.selectedLineHighlightColor = theme.selectedLineColor
                textView.needsDisplay = true
            }
        }
    }
    
    // MARK: - Plugin Performance
    
    func testPluginPerformance() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        
        // Add multiple plugins
        let plugin1 = CustomAnnotationPlugin()
        let plugin2 = CustomAnnotationPlugin()
        let plugin3 = CustomAnnotationPlugin()
        
        textView.addPlugin(plugin1)
        textView.addPlugin(plugin2)
        textView.addPlugin(plugin3)
        
        let lines = (1...1000).map { "Line \($0): Text with plugins" }
        let text = lines.joined(separator: "\n")
        
        measure {
            textView.text = text
            textView.layoutSubtreeIfNeeded()
        }
    }
    
    // MARK: - Memory Performance
    
    func testMemoryUsageWithLargeDocument() async {
        autoreleasepool {
            let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
            
            // Load very large document
            let lines = (1...50000).map { "Line \($0): This is a line of text for memory testing." }
            let hugeText = lines.joined(separator: "\n")
            
            textView.text = hugeText
            textView.layoutSubtreeIfNeeded()
            
            // Check that text view still functions
            XCTAssertEqual(textView.text, hugeText, "Text should be preserved")
            
            // Clear text
            textView.text = ""
            textView.layoutSubtreeIfNeeded()
        }
        
        // Memory should be released after autoreleasepool
    }
    
    // MARK: - Configuration Performance
    
    func testConfigurationSwitchingPerformance() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        textView.text = SampleCodeProvider.getCode(for: .swift)
        
        let configurations = [
            EditorConfiguration.fullFeatured,
            EditorConfiguration.minimal,
            EditorConfiguration.markdown,
            EditorConfiguration.presentation
        ]
        
        measure {
            for config in configurations {
                // Apply configuration
                textView.showsLineNumbers = config.showLineNumbers
                textView.isEditable = config.isEditable
                textView.showsInvisibleCharacters = config.showInvisibleCharacters
                textView.highlightSelectedLine = config.highlightSelectedLine
                textView.font = NSFont.monospacedSystemFont(ofSize: config.fontSize, weight: .regular)
                textView.layoutSubtreeIfNeeded()
            }
        }
    }
    
    // MARK: - Viewport Performance
    
    func testViewportLayoutPerformance() async {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        
        // Create document with varied line lengths
        var lines: [String] = []
        for i in 1...2000 {
            let lineLength = Int.random(in: 20...200)
            let line = String(repeating: "x", count: lineLength)
            lines.append("Line \(i): \(line)")
        }
        
        textView.text = lines.joined(separator: "\n")
        
        measure {
            // Force viewport updates
            for _ in 1...10 {
                textView.layoutSubtreeIfNeeded()
                textView.textLayoutManager.textViewportLayoutController.layoutViewport()
            }
        }
    }
}