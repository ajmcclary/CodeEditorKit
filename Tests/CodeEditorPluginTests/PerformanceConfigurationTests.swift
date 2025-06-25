@testable import CodeEditorPlugin
import XCTest

final class PerformanceConfigurationTests: XCTestCase {
    deinit {}
    
    // MARK: - Performance Tests
    
    @MainActor
    func testLargeTextPerformanceWithLineNumbers() {
        let textView = CodeEditorView()
        let largeText = String(repeating: "This is a line of text.\n", count: 10_000)
        
        measure {
            textView.text = largeText
            textView.showsLineNumbers = true
            textView.needsDisplay = true
        }
    }
    
    @MainActor
    func testLargeTextPerformanceWithoutLineNumbers() {
        let textView = CodeEditorView()
        let largeText = String(repeating: "This is a line of text.\n", count: 10_000)
        
        measure {
            textView.text = largeText
            textView.showsLineNumbers = false
            textView.needsDisplay = true
        }
    }
    
    @MainActor
    func testSyntaxHighlightingPerformance() {
        let textView = CodeEditorView()
        let swiftCode = """
        import Foundation
        
        class Example {
            func doSomething() {
                for i in 0..<1000 {
                    print("Line \\(i)")
                }
            }
        }
        """
        let largeCode = String(repeating: swiftCode + "\n", count: 100)
        
        measure {
            textView.text = largeCode
            textView.language = .swift
            textView.isSyntaxHighlightingEnabled = true
        }
    }
    
    @MainActor
    func testScrollingPerformanceWithLargeText() {
        let textView = CodeEditorView()
        let largeText = String(repeating: "This is a long line of text that should wrap around. ", count: 1_000)
        textView.text = largeText
        textView.widthTracksTextView = true
        
        measure {
            // Simulate scrolling by changing the visible range
            if let textContainer = textView.textContainer,
               let layoutManager = textView.layoutManager {
                let glyphRange = layoutManager.glyphRange(for: textContainer)
                layoutManager.ensureLayout(for: textContainer)
                _ = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            }
        }
    }
    
    @MainActor
    func testConfigurationChangePerformance() {
        let textView = CodeEditorView()
        let sampleText = "Sample text for configuration testing"
        textView.text = sampleText
        
        measure {
            // Toggle multiple configurations
            textView.showsLineNumbers.toggle()
            textView.showsInvisibleCharacters.toggle()
            textView.highlightSelectedLine.toggle()
            textView.widthTracksTextView.toggle()
            textView.isHorizontallyResizable.toggle()
        }
    }
    
    @MainActor
    func testThemeSwitchingPerformance() {
        let textView = CodeEditorView()
        let sampleCode = """
        func example() {
            let text = "Hello, World!"
            print(text)
        }
        """
        textView.text = sampleCode
        textView.language = .swift
        textView.isSyntaxHighlightingEnabled = true
        
        let colorSchemes: [(bg: NSColor, text: NSColor, selectedLine: NSColor)] = [
            (.white, .black, NSColor.selectedTextBackgroundColor),
            (.black, .white, NSColor.selectedTextBackgroundColor.withAlphaComponent(0.3)),
            (NSColor(calibratedWhite: 0.98, alpha: 1.0), .black, NSColor.selectedTextBackgroundColor),
            (NSColor(calibratedWhite: 0.15, alpha: 1.0), NSColor(calibratedWhite: 0.9, alpha: 1.0), NSColor.selectedTextBackgroundColor.withAlphaComponent(0.3)),
            (.white, .black, NSColor(calibratedRed: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)),
            (NSColor(calibratedWhite: 0.05, alpha: 1.0), NSColor(calibratedWhite: 0.95, alpha: 1.0), NSColor.selectedTextBackgroundColor.withAlphaComponent(0.4))
        ]
        
        measure {
            for scheme in colorSchemes {
                textView.backgroundColor = scheme.bg
                textView.textColor = scheme.text
                textView.selectedLineHighlightColor = scheme.selectedLine
            }
        }
    }
    
    @MainActor
    func testSpellCheckingPerformanceImpact() {
        let textView = CodeEditorView()
        let textWithErrors = """
        This is a sampl text with mny speling erors.
        Ech line contans multipl mistaks that nedd to be checkd.
        The spel checker shoud find all thse erors.
        """
        let largeTextWithErrors = String(repeating: textWithErrors + "\n", count: 100)
        
        textView.text = largeTextWithErrors
        
        measure {
            textView.isContinuousSpellCheckingEnabled = true
            textView.checkTextInDocument(nil)
        }
    }
    
    @MainActor
    func testTextSubstitutionPerformance() {
        let textView = CodeEditorView()
        let textWithSubstitutions = """
        This is a test -- with dashes...
        "Smart quotes" should be replaced.
        (c) (r) (tm) should become symbols.
        """
        let largeText = String(repeating: textWithSubstitutions + "\n", count: 100)
        
        measure {
            textView.text = largeText
            textView.isAutomaticQuoteSubstitutionEnabled = true
            textView.isAutomaticDashSubstitutionEnabled = true
            textView.isAutomaticTextReplacementEnabled = true
        }
    }
    
    @MainActor
    func testHardwareAccelerationImpact() {
        let textView = CodeEditorView()
        let largeText = String(repeating: "This is a line of text.\n", count: 5_000)
        textView.text = largeText
        
        // Test that hardware acceleration features can be configured
        textView.wantsLayer = true
        XCTAssertTrue(textView.wantsLayer, "Hardware acceleration should be enabled")
        XCTAssertNotNil(textView.layer, "Layer should be created for hardware acceleration")
        
        // Configure layer for async drawing
        textView.layer?.drawsAsynchronously = true
        XCTAssertTrue(textView.layer?.drawsAsynchronously ?? false, "Asynchronous drawing should be enabled")
        
        // Test that rendering works with hardware acceleration
        textView.needsDisplay = true
        
        // Verify that the text view maintains its content with hardware acceleration
        XCTAssertEqual(textView.text, largeText, "Text content should remain unchanged with hardware acceleration")
        
        // Test disabling async drawing
        textView.layer?.drawsAsynchronously = false
        XCTAssertFalse(textView.layer?.drawsAsynchronously ?? true, "Asynchronous drawing should be disabled")
    }
    
    @MainActor
    func testMemoryUsageWithLargeConfiguration() {
        // Create multiple text views with full configuration
        var textViews: [CodeEditorView] = []
        
        measure {
            for _ in 0..<10 {
                let tv = CodeEditorView()
                tv.text = String(repeating: "Sample text\n", count: 100)
                tv.showsLineNumbers = true
                tv.highlightSelectedLine = true
                tv.showsInvisibleCharacters = true
                tv.isSyntaxHighlightingEnabled = true
                tv.language = .swift
                tv.isContinuousSpellCheckingEnabled = true
                tv.isGrammarCheckingEnabled = true
                textViews.append(tv)
            }
            
            // Clean up
            textViews.removeAll()
        }
    }
    
    @MainActor
    func testLayoutPerformanceWithComplexConfiguration() {
        let textView = CodeEditorView()
        let complexText = """
        // TODO: This is a comment
        func complexFunction() {
            let longString = "This is a very long string that should wrap around and test the layout system"
            for i in 0..<100 {
                print("Iteration \\(i): \\(longString)")
            }
        }
        // FIXME: Another comment
        """
        
        textView.text = String(repeating: complexText + "\n", count: 50)
        textView.showsLineNumbers = true
        textView.highlightSelectedLine = true
        textView.widthTracksTextView = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        
        measure {
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        }
    }
}
