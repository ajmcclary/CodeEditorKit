#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest

final class PerformanceConfigurationTests: XCTestCase {
    deinit {}
    
    // MARK: - Performance Tests
    
    @MainActor
    func testLargeTextPerformanceWithLineNumbers() {
        let textView = CodeEditorView(frame: .zero)
        let largeText = String(repeating: "This is a line of text.\n", count: 10_000)
        
        measure {
            textView.text = largeText
            textView.showsLineNumbers = true
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.needsDisplay = true
            #elseif canImport(UIKit)
            textView.setNeedsDisplay()
            #endif
        }
    }
    
    @MainActor
    func testLargeTextPerformanceWithoutLineNumbers() {
        let textView = CodeEditorView(frame: .zero)
        let largeText = String(repeating: "This is a line of text.\n", count: 10_000)
        
        measure {
            textView.text = largeText
            textView.showsLineNumbers = false
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.needsDisplay = true
            #elseif canImport(UIKit)
            textView.setNeedsDisplay()
            #endif
        }
    }
    
    @MainActor
    func testSyntaxHighlightingPerformance() {
        let textView = CodeEditorView(frame: .zero)
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
        let textView = CodeEditorView(frame: .zero)
        let largeText = String(repeating: "This is a long line of text that should wrap around. ", count: 1_000)
        textView.text = largeText
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.textContainer?.widthTracksTextView = true
        #else
        textView.textContainer.widthTracksTextView = true
        #endif
        
        measure {
            // Simulate scrolling by changing the visible rect
            let visibleRect = CGRect(x: 0, y: 0, width: 400, height: 600)
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.scrollToVisible(visibleRect)
            #else
            textView.scrollRectToVisible(visibleRect, animated: false)
            #endif
            
            // Force layout to ensure scrolling performance is measured
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.needsDisplay = true
            #elseif canImport(UIKit)
            textView.setNeedsDisplay()
            #endif
        }
    }
    
    @MainActor
    func testConfigurationChangePerformance() {
        let textView = CodeEditorView(frame: .zero)
        let sampleText = "Sample text for configuration testing"
        textView.text = sampleText
        
        measure {
            // Toggle multiple configurations
            textView.showsLineNumbers.toggle()
            textView.showsInvisibleCharacters.toggle()
            textView.highlightSelectedLine.toggle()
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let container = textView.textContainer {
                container.widthTracksTextView.toggle()
            }
            #else
            textView.textContainer.widthTracksTextView.toggle()
            #endif
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.isHorizontallyResizable.toggle()
            #endif
        }
    }
    
    @MainActor
    func testThemeSwitchingPerformance() {
        let textView = CodeEditorView(frame: .zero)
        let sampleCode = """
        func example() {
            let text = "Hello, World!"
            print(text)
        }
        """
        textView.text = sampleCode
        textView.language = .swift
        textView.isSyntaxHighlightingEnabled = true
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let colorSchemes: [(bg: PlatformColor, text: PlatformColor, selectedLine: PlatformColor)] = [
            (.white, .black, NSColor.selectedTextBackgroundColor),
            (.black, .white, NSColor.selectedTextBackgroundColor.withAlphaComponent(0.3)),
            (NSColor(calibratedWhite: 0.98, alpha: 1.0), .black, NSColor.selectedTextBackgroundColor),
            (NSColor(calibratedWhite: 0.15, alpha: 1.0), NSColor(calibratedWhite: 0.9, alpha: 1.0), NSColor.selectedTextBackgroundColor.withAlphaComponent(0.3)),
            (.white, .black, NSColor(calibratedRed: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)),
            (NSColor(calibratedWhite: 0.05, alpha: 1.0), NSColor(calibratedWhite: 0.95, alpha: 1.0), NSColor.selectedTextBackgroundColor.withAlphaComponent(0.4))
        ]
        #elseif canImport(UIKit)
        // swiftlint:disable object_literal
        let colorSchemes: [(bg: PlatformColor, text: PlatformColor, selectedLine: PlatformColor)] = [
            (.white, .black, UIColor.systemGray4),
            (.black, .white, UIColor.systemGray4.withAlphaComponent(0.3)),
            (UIColor(white: 0.98, alpha: 1.0), .black, UIColor.systemGray4),
            (UIColor(white: 0.15, alpha: 1.0), UIColor(white: 0.9, alpha: 1.0), UIColor.systemGray4.withAlphaComponent(0.3)),
            (.white, .black, UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)),
            (UIColor(white: 0.05, alpha: 1.0), UIColor(white: 0.95, alpha: 1.0), UIColor.systemGray4.withAlphaComponent(0.4))
        ]
        // swiftlint:enable object_literal
        #endif
        
        measure {
            for scheme in colorSchemes {
                textView.backgroundColor = scheme.bg
                textView.textColor = scheme.text
                var config = textView.configuration
                config.display.selectedLineHighlightColor = scheme.selectedLine
                textView.configuration = config
            }
        }
    }
    
    @MainActor
    func testSpellCheckingPerformanceImpact() {
        let textView = CodeEditorView(frame: .zero)
        let textWithErrors = """
        This is a sampl text with mny speling erors.
        Ech line contans multipl mistaks that nedd to be checkd.
        The spel checker shoud find all thse erors.
        """
        let largeTextWithErrors = String(repeating: textWithErrors + "\n", count: 100)
        
        textView.text = largeTextWithErrors
        
        measure {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.isContinuousSpellCheckingEnabled = true
            textView.checkTextInDocument(nil)
            #elseif canImport(UIKit)
            textView.spellCheckingType = .yes
            #endif
        }
    }
    
    @MainActor
    func testTextSubstitutionPerformance() {
        let textView = CodeEditorView(frame: .zero)
        let textWithSubstitutions = """
        This is a test -- with dashes...
        "Smart quotes" should be replaced.
        (c) (r) (tm) should become symbols.
        """
        let largeText = String(repeating: textWithSubstitutions + "\n", count: 100)
        
        measure {
            textView.text = largeText
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.isAutomaticQuoteSubstitutionEnabled = true
            textView.isAutomaticDashSubstitutionEnabled = true
            textView.isAutomaticTextReplacementEnabled = true
            #elseif canImport(UIKit)
            textView.smartQuotesType = .yes
            textView.smartDashesType = .yes
            textView.autocorrectionType = .yes
            #endif
        }
    }
    
    @MainActor
    func testHardwareAccelerationImpact() {
        let textView = CodeEditorView(frame: .zero)
        let largeText = String(repeating: "This is a line of text.\n", count: 5_000)
        textView.text = largeText
        
        // Test that hardware acceleration features can be configured
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        #elseif canImport(UIKit)
        // UIKit always uses layers
        XCTAssertNotNil(textView.layer, "Layer should always exist in UIKit")
        
        // Configure layer for async drawing
        textView.layer.drawsAsynchronously = true
        XCTAssertTrue(textView.layer.drawsAsynchronously, "Asynchronous drawing should be enabled")
        
        // Test that rendering works with hardware acceleration
        textView.setNeedsDisplay()
        
        // Verify that the text view maintains its content with hardware acceleration
        XCTAssertEqual(textView.text, largeText, "Text content should remain unchanged with hardware acceleration")
        
        // Test disabling async drawing
        textView.layer.drawsAsynchronously = false
        XCTAssertFalse(textView.layer.drawsAsynchronously, "Asynchronous drawing should be disabled")
        #endif
    }
    
    @MainActor
    func testMemoryUsageWithLargeConfiguration() {
        // Create multiple text views with full configuration
        var textViews: [CodeEditorView] = []
        
        measure {
            for _ in 0..<10 {
                let tv = CodeEditorView(frame: .zero)
                tv.text = String(repeating: "Sample text\n", count: 100)
                tv.showsLineNumbers = true
                tv.highlightSelectedLine = true
                tv.showsInvisibleCharacters = true
                tv.isSyntaxHighlightingEnabled = true
                tv.language = .swift
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                tv.isContinuousSpellCheckingEnabled = true
                tv.isGrammarCheckingEnabled = true
                #elseif canImport(UIKit)
                tv.spellCheckingType = .yes
                #endif
                textViews.append(tv)
            }
            
            // Clean up
            textViews.removeAll()
        }
    }
    
    @MainActor
    func testLayoutPerformanceWithComplexConfiguration() {
        let textView = CodeEditorView(frame: .zero)
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.textContainer?.widthTracksTextView = true
        #else
        textView.textContainer.widthTracksTextView = true
        #endif
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        #elseif canImport(UIKit)
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        #endif
        
        measure {
            // Force layout using TextKit2-compatible method
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.layout()
            #elseif canImport(UIKit)
            textView.layoutIfNeeded()
            #endif
        }
    }
}
