import CodeEditorConfiguration
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
import SwiftUI
#endif

/// Tests for auto-scroll behavior in CodeEditorPlugin
final class AutoScrollTests: XCTestCase {
    // MARK: - Basic Configuration Tests

    func testDefaultAutoScrollBehavior() {
        let config = EditorConfiguration()
        XCTAssertFalse(config.behavior.autoScrollToCursor, "Default autoScrollToCursor should be false")
    }

    func testEnableAutoScroll() {
        var config = EditorConfiguration()
        config.behavior.autoScrollToCursor = true
        XCTAssertTrue(config.behavior.autoScrollToCursor, "autoScrollToCursor should be true after setting")
    }

    func testAutoScrollInConfigurationPresets() {
        // Test default preset
        let defaultConfig = EditorConfiguration.default
        XCTAssertFalse(defaultConfig.behavior.autoScrollToCursor, "Default preset should have autoScrollToCursor = false")

        // Test minimal preset
        let minimalConfig = EditorConfiguration.minimal
        XCTAssertFalse(minimalConfig.behavior.autoScrollToCursor, "Minimal preset should have autoScrollToCursor = false")

        // Test readOnly preset
        let readOnlyConfig = EditorConfiguration.readOnly
        XCTAssertFalse(readOnlyConfig.behavior.autoScrollToCursor, "ReadOnly preset should have autoScrollToCursor = false")

        // Test markdown preset
        let markdownConfig = EditorConfiguration.markdown
        XCTAssertFalse(markdownConfig.behavior.autoScrollToCursor, "Markdown preset should have autoScrollToCursor = false")

        // Test presentation preset
        let presentationConfig = EditorConfiguration.presentation
        XCTAssertFalse(presentationConfig.behavior.autoScrollToCursor, "Presentation preset should have autoScrollToCursor = false")
    }

    func testAutoScrollConfigurationCopying() {
        var config = EditorConfiguration()
        config.behavior.autoScrollToCursor = true

        // Test that copying preserves the value
        let copiedConfig = config
        XCTAssertTrue(copiedConfig.behavior.autoScrollToCursor, "Copied configuration should preserve autoScrollToCursor")
    }

    // MARK: - CodeEditorView Extension Tests

    @MainActor
    func testSetSelectedRangeWithoutScrollingMethod() async {
        // Test that the method exists on CodeEditorView
        let editorView = CodeEditorView()

        // Set up the view with proper bounds on macOS to avoid geometry warnings
        #if canImport(AppKit)
        editorView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        editorView.bounds = NSRect(x: 0, y: 0, width: 400, height: 300)
        if let scrollView = editorView.enclosingScrollView {
            scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        }
        #else
        editorView.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        editorView.bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        #endif

        // Set some text
        #if canImport(AppKit)
        editorView.string = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        #else
        editorView.text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        #endif

        // Test that we can call the method
        let testRange = NSRange(location: 10, length: 5)
        editorView.setSelectedRangeWithoutScrolling(testRange)

        // Verify the selection was set
        XCTAssertEqual(editorView.selectedRange, testRange, "Selected range should be set correctly")
    }

    @MainActor
    func testOverriddenSelectedRangeProperty() async {
        let editorView = CodeEditorView()
        var config = EditorConfiguration()

        // Set up the view with proper bounds on macOS to avoid geometry warnings
        #if canImport(AppKit)
        editorView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        editorView.bounds = NSRect(x: 0, y: 0, width: 400, height: 300)
        if let scrollView = editorView.enclosingScrollView {
            scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        }
        #else
        editorView.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        editorView.bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        #endif

        // Test with autoScrollToCursor = false
        config.behavior.autoScrollToCursor = false
        editorView.configuration = config

        #if canImport(AppKit)
        editorView.string = "Test text for selection"
        #else
        editorView.text = "Test text for selection"
        #endif

        // Set selected range
        let testRange = NSRange(location: 5, length: 4)
        editorView.selectedRange = testRange

        // Verify it was set
        XCTAssertEqual(editorView.selectedRange, testRange, "Selected range should be set")
    }

    // MARK: - SwiftUI Modifier Tests

    #if canImport(SwiftUI)
    @MainActor
    @available(macOS 13.0, iOS 16.0, *)
    func testAutoScrollToCursorModifier() async {
        // Test that the SwiftUI modifier exists and can be used
        let binding = Binding.constant("test code")

        // Create editor with modifier
        let editor = CodeEditor(text: binding)
            .autoScrollToCursor(true)

        // The test passes if it compiles - we're validating the API exists
        XCTAssertNotNil(editor, "Should be able to create CodeEditor with autoScrollToCursor modifier")
    }
    #endif

    // MARK: - Integration Test Helpers

    @MainActor
    func testAutoScrollBehaviorIntegration() async {
        let editorView = CodeEditorView()
        var config = EditorConfiguration()

        // Set up the view with proper bounds on macOS to avoid geometry warnings
        #if canImport(AppKit)
        editorView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        editorView.bounds = NSRect(x: 0, y: 0, width: 400, height: 300)
        if let scrollView = editorView.enclosingScrollView {
            scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        }
        #else
        editorView.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        editorView.bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        #endif

        // Test enabling auto-scroll
        config.behavior.autoScrollToCursor = true
        editorView.configuration = config

        XCTAssertTrue(editorView.configuration.behavior.autoScrollToCursor, "EditorView should reflect configuration")

        // Test disabling auto-scroll
        config.behavior.autoScrollToCursor = false
        editorView.configuration = config

        XCTAssertFalse(editorView.configuration.behavior.autoScrollToCursor, "EditorView should reflect updated configuration")
    }

    // MARK: - Configuration With Method Test

    func testConfigurationWithAutoScrollMethod() {
        let config = EditorConfiguration()

        // Create a new behavior with autoScrollToCursor enabled
        var newBehavior = config.behavior
        newBehavior.autoScrollToCursor = true

        // Use the with method to create a new configuration with the updated behavior
        let newConfig = config.with(behavior: newBehavior)

        // Original should be unchanged
        XCTAssertFalse(config.behavior.autoScrollToCursor, "Original config should remain unchanged")

        // New config should have the updated value
        XCTAssertTrue(newConfig.behavior.autoScrollToCursor, "New config should have autoScrollToCursor = true")
    }
}
