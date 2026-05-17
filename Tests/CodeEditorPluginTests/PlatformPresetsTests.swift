import CodeEditorConfiguration
@testable import CodeEditorPlugin
import XCTest

final class PlatformPresetsTests: XCTestCase {
    func testIOSPreset() {
        let config = EditorConfiguration.iOS

        // Verify iOS optimizations
        XCTAssertEqual(config.display.fontSize, 16.0, "iOS should have larger font size for touch")
        XCTAssertEqual(config.layout.gutterWidth, 50.0, "iOS should have wider gutter for touch targets")
        XCTAssertTrue(config.behavior.isCodeCompletionEnabled, "iOS should support code completion")
        XCTAssertFalse(config.behavior.isAutomaticTextReplacementEnabled, "iOS should disable auto text replacement for performance")
        XCTAssertEqual(config.performance.maxSyntaxHighlightingLength, 100_000, "iOS should have smaller syntax highlighting limit")
        XCTAssertTrue(config.performance.smoothScrolling, "iOS should enable smooth scrolling")
    }

    func testMacOSPreset() {
        let config = EditorConfiguration.macOS

        // Verify macOS optimizations
        XCTAssertEqual(config.display.fontSize, 14.0, "macOS should have standard font size")
        XCTAssertEqual(config.layout.gutterWidth, 40.0, "macOS should have standard gutter width")
        XCTAssertTrue(config.behavior.isCodeCompletionEnabled, "macOS should support code completion")
        XCTAssertTrue(config.behavior.isAutomaticTextReplacementEnabled, "macOS should enable auto text replacement")
        XCTAssertTrue(config.behavior.isAutomaticQuoteSubstitutionEnabled, "macOS should enable auto quote substitution")
        XCTAssertTrue(config.performance.useHardwareAcceleration, "macOS should use hardware acceleration")
        XCTAssertEqual(config.performance.maxSyntaxHighlightingLength, 500_000, "macOS should have large syntax highlighting limit")
    }

    func testPlatformOptimizedPreset() {
        let config = EditorConfiguration.platformOptimized

        // Should return a valid configuration
        XCTAssertNotNil(config)

        // Should have platform-appropriate settings based on compile-time platform
        #if canImport(UIKit)
        XCTAssertEqual(config.display.fontSize, 16.0)
        #elseif canImport(AppKit)
        XCTAssertEqual(config.display.fontSize, 14.0)
        #else
        XCTAssertEqual(config.display.fontSize, 13.0) // default fontSize
        #endif
    }

    func testPresetsDifferFromDefault() {
        let defaultConfig = EditorConfiguration.default

        // Each platform preset should differ from default
        XCTAssertNotEqual(EditorConfiguration.iOS.display.fontSize, defaultConfig.display.fontSize)
        XCTAssertNotEqual(EditorConfiguration.macOS.layout.gutterWidth, defaultConfig.layout.gutterWidth)

        // Platform presets should have distinct characteristics
        XCTAssertNotEqual(EditorConfiguration.iOS.display.fontSize, EditorConfiguration.macOS.display.fontSize)
        XCTAssertNotEqual(EditorConfiguration.iOS.performance.maxSyntaxHighlightingLength,
                         EditorConfiguration.macOS.performance.maxSyntaxHighlightingLength)
    }
}
