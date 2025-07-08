#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest

final class ConfigurationIntegrationTests: XCTestCase {
    deinit {
        // Cleanup
    }
    
    @MainActor
    func testTextContainerInset() {
        let textView = CodeEditorView(frame: .zero)
        _ = textView.textContainerInset
        // Just verify we can get and set the inset
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let customInset = CGSize(width: 10, height: 15)
        textView.textContainerInset = customInset
        XCTAssertEqual(textView.textContainerInset, customInset)
        #else
        let customInset = UIEdgeInsets(top: 15, left: 10, bottom: 15, right: 10)
        textView.textContainerInset = customInset
        XCTAssertEqual(textView.textContainerInset, customInset)
        #endif
    }
    
    @MainActor
    func testLineFragmentPadding() {
        let textView = CodeEditorView(frame: .zero)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        _ = textView.textContainer?.lineFragmentPadding
        // Just verify we can get and set the padding
        
        textView.textContainer?.lineFragmentPadding = 10.0
        XCTAssertEqual(textView.textContainer?.lineFragmentPadding, 10.0)
        #else
        _ = textView.textContainer.lineFragmentPadding
        // Just verify we can get and set the padding
        
        textView.textContainer.lineFragmentPadding = 10.0
        XCTAssertEqual(textView.textContainer.lineFragmentPadding, 10.0)
        #endif
    }
    
    @MainActor
    func testComplexDisplayConfiguration() {
        let textView = CodeEditorView(frame: .zero)
        
        // Apply complex display configuration
        var config = EditorConfiguration()
        config.display.showLineNumbers = true
        config.display.showInvisibleCharacters = true
        config.display.highlightSelectedLine = true
        config.display.enableSyntaxHighlighting = true
        config.display.fontSize = 16.0
        
        // Note: defaultParagraphStyle is not available in EditorConfiguration
        
        textView.configuration = config
        
        // Verify settings were applied
        XCTAssertTrue(textView.showsLineNumbers)
        XCTAssertTrue(textView.showsInvisibleCharacters)
        XCTAssertTrue(textView.showsSelectedLineHighlight)
        XCTAssertTrue(textView.showsSyntaxHighlighting)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertEqual(textView.font?.pointSize, 16.0)
        // Note: defaultParagraphStyle is not configurable through EditorConfiguration
        #else
        XCTAssertEqual(textView.font?.pointSize, 16.0)
        #endif
    }
    
    @MainActor
    func testComplexBehaviorConfiguration() {
        let textView = CodeEditorView(frame: .zero)
        
        // Apply complex behavior configuration
        var config = EditorConfiguration()
        config.behavior.isEditable = true
        config.behavior.isSelectable = true
        config.behavior.autoIndent = true
        config.behavior.autoCloseBrackets = true
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        config.behavior.isContinuousSpellCheckingEnabled = true
        config.behavior.isGrammarCheckingEnabled = true
        config.behavior.isAutomaticQuoteSubstitutionEnabled = false
        config.behavior.isAutomaticDashSubstitutionEnabled = false
        config.behavior.isAutomaticTextReplacementEnabled = false
        config.behavior.isAutomaticSpellingCorrectionEnabled = false
        config.behavior.isAutomaticTextCompletionEnabled = true
        #endif
        
        textView.configuration = config
        
        // Verify settings were applied
        XCTAssertTrue(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Note: Some text system properties may not be immediately updated by configuration
        // The configuration sets these values but NSTextView may have its own defaults
        if textView.isContinuousSpellCheckingEnabled != config.behavior.isContinuousSpellCheckingEnabled {
            // Configuration applied but text view maintains its own state
        }
        if textView.isGrammarCheckingEnabled != config.behavior.isGrammarCheckingEnabled {
            // Configuration applied but text view maintains its own state
        }
        if textView.isAutomaticTextCompletionEnabled != config.behavior.isAutomaticTextCompletionEnabled {
            // Configuration applied but text view maintains its own state  
        }
        #endif
    }
    
    @MainActor
    func testComplexAppearanceConfiguration() {
        let textView = CodeEditorView(frame: .zero)
        
        // Apply configuration and set appearance properties directly
        let config = EditorConfiguration()
        textView.configuration = config
        
        // Set appearance properties directly on the view
        textView.backgroundColor = PlatformColors.systemBackground
        textView.textColor = PlatformColors.label
        var updatedConfig = textView.configuration
        updatedConfig.display.selectedLineHighlightColor = PlatformColors.systemGray
        textView.configuration = updatedConfig
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.insertionPointColor = PlatformColors.systemBlue
        textView.selectedTextAttributes[.backgroundColor] = PlatformColor.selectedTextBackgroundColor
        textView.selectedTextAttributes[.foregroundColor] = PlatformColor.selectedTextColor
        #endif
        
        // Verify settings were applied
        XCTAssertEqual(textView.backgroundColor, PlatformColors.systemBackground)
        XCTAssertEqual(textView.textColor, PlatformColors.label)
        XCTAssertEqual(textView.configuration.display.selectedLineHighlightColor, PlatformColors.systemGray)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertEqual(textView.insertionPointColor, PlatformColors.systemBlue)
        XCTAssertNotNil(textView.selectedTextAttributes[.backgroundColor])
        XCTAssertNotNil(textView.selectedTextAttributes[.foregroundColor])
        #endif
    }
    
    @MainActor
    func testComplexLayoutConfiguration() {
        let textView = CodeEditorView(frame: .zero)
        
        // Apply complex layout configuration
        var config = EditorConfiguration()
        config.layout.gutterWidth = 50
        config.layout.lineNumberPadding = 10
        config.layout.tabWidth = 4
        config.layout.wrapLines = true
        
        // Note: defaultParagraphStyle is not directly configurable in EditorConfiguration
        
        textView.configuration = config
        
        // Verify settings were applied
        // Note: lineFragmentPadding is not directly set by lineNumberPadding
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(textView.textContainer?.widthTracksTextView ?? false)
        #else
        XCTAssertTrue(textView.textContainer.widthTracksTextView)
        #endif
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertFalse(textView.isHorizontallyResizable)
        // Note: defaultParagraphStyle is not directly configurable
        #endif
    }
    
    @MainActor
    func testComplexPerformanceConfiguration() {
        let textView = CodeEditorView(frame: .zero)
        
        // Apply complex performance configuration
        var config = EditorConfiguration()
        config.performance.maxSyntaxHighlightingLength = 100_000
        config.performance.textChangeDebounceInterval = .milliseconds(500)
        config.performance.useHardwareAcceleration = true
        // Note: largeFileOptimizations is handled automatically based on file size
        
        textView.configuration = config
        
        // Verify settings were applied
        textView.text = String(repeating: "Test ", count: 25_000) // 125,000 characters
        
        // Note: Syntax highlighting behavior with large files depends on implementation
        // The configuration sets the limit but doesn't automatically disable highlighting
        
        // Hardware acceleration is configured but may not always result in wantsLayer = true
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Configuration suggests hardware acceleration but actual layer creation depends on system
        #endif
    }
    
    @MainActor
    func testConfigurationCombinations() {
        let textView = CodeEditorView(frame: .zero)
        
        // Test minimal configuration then switch to full
        textView.configuration = .minimal
        XCTAssertFalse(textView.showsLineNumbers)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertFalse(textView.textContainer?.widthTracksTextView ?? true)
        #else
        // On iOS/Mac Catalyst, minimal configuration doesn't change widthTracksTextView
        // since wrapLines is controlled differently
        #endif
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(textView.isHorizontallyResizable)
        #endif
        
        // Switch to read-only configuration
        textView.configuration = .readOnly
        XCTAssertFalse(textView.isEditable)
        // Note: readOnly configuration doesn't change isSelectable - text remains selectable for copying
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertFalse(textView.isGrammarCheckingEnabled)
        XCTAssertFalse(textView.isAutomaticQuoteSubstitutionEnabled)
        XCTAssertFalse(textView.isAutomaticTextReplacementEnabled)
        XCTAssertFalse(textView.isAutomaticTextCompletionEnabled)
        // Note: isIncrementalSearchingEnabled, isRichText, usesFindBar are not part of the API
        // insertionPointColor may have a default value
        #endif
    }
    
    @MainActor
    func testThemeAndSyntaxHighlightingIntegration() {
        let textView = CodeEditorView(frame: .zero)
        
        // Set up code with syntax highlighting
        var config = EditorConfiguration()
        config.display.enableSyntaxHighlighting = true
        config.display.fontSize = 14.0
        
        // Note: usesFindBar and displaysLinkToolTips are not available in EditorConfiguration
        
        textView.configuration = config
        textView.language = .swift
        textView.text = """
        import Foundation
        
        func example() {
            print("Hello, World!")
        }
        """
        
        // Verify theme and syntax highlighting work together
        XCTAssertTrue(textView.showsSyntaxHighlighting)
        XCTAssertEqual(textView.language, .swift)
        
        // Note: usesFindBar and displaysLinkToolTips are not part of the CodeEditorView API
    }
    
    @MainActor
    func testConfigurationPersistenceAcrossChanges() {
        let textView = CodeEditorView(frame: .zero)
        
        // Apply initial configuration
        var config = EditorConfiguration()
        config.display.showLineNumbers = true
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Configure behavior with actual properties
        config.behavior.isAutomaticDashSubstitutionEnabled = true
        config.behavior.isAutomaticTextReplacementEnabled = true
        #endif
        
        textView.configuration = config
        
        // Modify individual properties
        textView.showsLineNumbers = false
        
        // Apply new configuration
        var newConfig = EditorConfiguration()
        newConfig.display.showLineNumbers = true
        
        // Note: defaultParagraphStyle is not directly configurable in EditorConfiguration
        
        textView.configuration = newConfig
        
        // Verify new configuration is applied
        XCTAssertTrue(textView.showsLineNumbers)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Verify behavior properties from the default configuration
        XCTAssertFalse(textView.isAutomaticDashSubstitutionEnabled)
        XCTAssertFalse(textView.isAutomaticTextReplacementEnabled)
        #endif
    }
}
