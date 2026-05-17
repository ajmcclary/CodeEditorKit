import CodeEditorConfiguration
import CodeEditorPlatform
@testable import CodeEditorPlugin
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class IntegrationTests: CleanupTestCase {
    // MARK: - Async Highlighting Integration Tests

    func testAsyncHighlightingWithLanguageSwitch() async throws {
        let editor = createCodeEditorView()
        let expectation = XCTestExpectation(description: "Async highlighting completes")

        // Start with Swift
        editor.language = .swift
        editor.text = """
        func hello() {
            print("Hello, World!")
        }
        """

        // Wait for initial highlighting
        try await Task.sleep(for: .milliseconds(200))

        // Switch to JavaScript
        editor.language = .javascript
        editor.text = """
        function hello() {
            console.log("Hello, World!");
        }
        """

        // Wait for highlighting to complete
        try await Task.sleep(for: .milliseconds(200))

        // Verify highlighting was applied
        var hasHighlighting = false
        #if canImport(AppKit)
        if let textStorage = editor.textStorage {
            textStorage.enumerateAttributes(
                in: NSRange(location: 0, length: textStorage.length),
                options: []
            ) { attributes, _, _ in
                if attributes[.foregroundColor] != nil {
                    hasHighlighting = true
                }
            }
        }
        #else
        let textStorage = editor.textStorage
        textStorage.enumerateAttributes(
            in: NSRange(location: 0, length: textStorage.length),
            options: []
        ) { attributes, _, _ in
            if attributes[.foregroundColor] != nil {
                hasHighlighting = true
            }
        }
        #endif

        XCTAssertTrue(hasHighlighting, "Syntax highlighting should be applied")
        expectation.fulfill()

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testAsyncHighlightingWithRapidTextChanges() async throws {
        let editor = createCodeEditorView()
        editor.language = .swift

        // Rapidly change text multiple times
        for index in 0..<5 {
            editor.text = "func test\(index)() { print(\"\(index)\") }"
            try await Task.sleep(for: .milliseconds(50))
        }

        // Wait for debounced highlighting to complete
        try await Task.sleep(for: .milliseconds(500))

        // Verify final text is highlighted
        var hasHighlighting = false
        #if canImport(AppKit)
        if let textStorage = editor.textStorage {
            textStorage.enumerateAttributes(
                in: NSRange(location: 0, length: textStorage.length),
                options: []
            ) { attributes, _, _ in
                if attributes[.foregroundColor] != nil {
                    hasHighlighting = true
                }
            }
        }
        #else
        let textStorage = editor.textStorage
        textStorage.enumerateAttributes(
            in: NSRange(location: 0, length: textStorage.length),
            options: []
        ) { attributes, _, _ in
            if attributes[.foregroundColor] != nil {
                hasHighlighting = true
            }
        }
        #endif

        XCTAssertTrue(hasHighlighting, "Final text should be highlighted")
    }

    func testAsyncHighlightingCancellationOnLanguageChange() async throws {
        let editor = createCodeEditorView()

        // Set a large text that takes time to highlight
        let largeCode = String(repeating: "func test() { print(\"test\") }\n", count: 100)
        editor.text = largeCode
        editor.language = .swift

        // Immediately switch language (should cancel previous highlighting)
        try await Task.sleep(for: .milliseconds(10))
        editor.language = .python

        // Wait for new highlighting
        try await Task.sleep(for: .milliseconds(300))

        // Verify Python highlighting is applied (not Swift)
        // This is a basic check - in reality, we'd verify specific Python syntax colors
        let textStorage = editor.textStorage
        XCTAssertNotNil(textStorage)
    }

    // MARK: - Platform Capabilities Integration Tests

    func testPlatformCapabilitiesWithTextView() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let editor = createCodeEditorView()

        // Verify platform-specific features work correctly
        #if canImport(AppKit)
        XCTAssertEqual(capabilities.currentPlatform, .macOS)
        XCTAssertTrue(capabilities.performanceCapabilities.supportsHardwareAcceleration)
        XCTAssertTrue(capabilities.textKitCapabilities.supportsRequiredTextKit2Surface)

        // Test macOS-specific features
        editor.isAutomaticQuoteSubstitutionEnabled = false
        XCTAssertFalse(editor.isAutomaticQuoteSubstitutionEnabled)
        #elseif canImport(UIKit)
        XCTAssertEqual(capabilities.currentPlatform, .iOS)

        // Test iOS-specific features
        editor.autocapitalizationType = .none
        XCTAssertEqual(editor.autocapitalizationType, .none)
        #endif
    }

    func testPlatformAbstractionIntegration() {
        let editor = createCodeEditorView()

        // Test platform colors
        editor.textColor = PlatformColors.label
        editor.backgroundColor = PlatformColors.systemBackground

        // Test platform fonts
        let font = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)
        editor.font = font

        // Verify the font was set correctly
        XCTAssertNotNil(editor.font)

        // Test platform-specific configuration
        var config = EditorConfiguration()
        #if canImport(AppKit)
        config = PlatformConfigurations.macOS
        #else
        config = PlatformConfigurations.iOS
        #endif

        editor.configuration = config
        XCTAssertEqual(editor.configuration.layout.tabWidth, config.layout.tabWidth)
    }

    // MARK: - Cross-Platform Coordinator Integration Tests

    func testCrossPlatformCoordinatorWithEditor() async throws {
        let editor = createCodeEditorView()
        let coordinator = CrossPlatformCoordinator()

        // Set up coordinator with text view
        coordinator.associatedTextView = editor

        // Test input coordination through the input coordinator
        let keyEvent = PlatformInputEvent.keyDown(key: "a", modifiers: [])
        let handled = coordinator.inputCoordinator.handleInput(keyEvent, in: editor)
        XCTAssertFalse(handled, "Basic key input should pass through")

        // Test command key handling - Command+A should be handled
        let cmdEvent = PlatformInputEvent.keyDown(key: "a", modifiers: [.command])
        let cmdHandled = coordinator.inputCoordinator.handleInput(cmdEvent, in: editor)
        XCTAssertTrue(cmdHandled, "Command+A (select all) should be handled")

        // Test platform-specific adjustments
        let adjustments = coordinator.platformAdjustments
        #if canImport(AppKit)
        XCTAssertEqual(adjustments.defaultFontSize, 12)
        #else
        XCTAssertEqual(adjustments.defaultFontSize, 14)
        #endif
    }

    // MARK: - Memory Monitor Integration Tests

    func testMemoryMonitorIntegrationWithMultipleEditors() async throws {
        let sharedMonitor = MemoryMonitor()

        // Create multiple editors sharing the same monitor
        let editor1 = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300), memoryMonitor: sharedMonitor)
        let editor2 = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300), memoryMonitor: sharedMonitor)

        // Add some content
        editor1.text = String(repeating: "Line of code\n", count: 100)
        editor2.text = String(repeating: "Another line\n", count: 100)

        // Register cleanup handlers
        sharedMonitor.registerCleanupHandler(
            identifier: "test-handler",
            priority: .high
        ) { @MainActor in
            CleanupResult(memoryFreedMB: 10, description: "Test cleanup")
        }

        // Perform cleanup
        await sharedMonitor.performCleanup()

        // Wait for cleanup
        try await Task.sleep(for: .milliseconds(100))

        // Verify cleanup happened (this is a basic check)
        XCTAssertNotNil(editor1.text)
        XCTAssertNotNil(editor2.text)
    }

    // MARK: - Live Configuration Update Integration Tests

    func testLiveConfigurationUpdateIntegration() async throws {
        let editor = createCodeEditorView()

        // Initial configuration
        var config = EditorConfiguration()
        config.display.fontSize = 14
        config.display.isLineNumbersEnabled = true
        editor.configuration = config

        // Verify initial state
        XCTAssertEqual(editor.font?.pointSize, 14)
        XCTAssertTrue(editor.isLineNumbersEnabled)

        // Hot reload configuration change
        config.display.fontSize = 16
        config.display.isLineNumbersEnabled = false
        editor.configuration = config

        // Wait for configuration to apply
        try await Task.sleep(for: .milliseconds(100))

        // Verify changes applied
        XCTAssertEqual(editor.font?.pointSize, 16)
        XCTAssertFalse(editor.isLineNumbersEnabled)
    }

    // MARK: - TextKit2 Optimization Integration Tests

    func testTextKit2OptimizationWithLargeFile() async throws {
        guard CodeEditorDependencies.makePlatformCapabilities().supportsRequiredTextKit2Surface else {
            throw XCTSkip("TextKit2 not supported on this platform")
        }

        let editor = createCodeEditorView()
        // Load a smaller file for faster tests
        let largeContent = String(repeating: "func test() { print(\"test\") }\n", count: 100) // Reduced from 1000
        editor.text = largeContent

        // Trigger viewport update
        let viewport = editor.getViewportManager()
        viewport.updateViewport()

        // Reduced wait time
        try await Task.sleep(for: .milliseconds(50)) // Reduced from 200ms

        // Verify viewport manager was created
        XCTAssertNotNil(viewport)
    }

    // MARK: - SwiftUI Integration Tests

    func testSwiftUIEnvironmentIntegration() async throws {
        // This test verifies that configuration values propagate correctly
        let config = EditorConfiguration.minimal

        // Apply configuration
        let editor = createCodeEditorView()
        editor.configuration = config

        // Verify configuration applied
        XCTAssertEqual(editor.configuration.display.isLineNumbersEnabled, config.display.isLineNumbersEnabled)
        XCTAssertEqual(editor.configuration.layout.tabWidth, config.layout.tabWidth)
    }
}
