//
//  CodeEditorSwiftUIViewTests.swift
//  CodeEditorPluginTests
//
//  Created on 2025-06-27.
//

@testable import CodeEditorPlugin
import SwiftUI
import XCTest

@available(macOS 12.0, iOS 16.0, *)
@MainActor
final class CodeEditorSwiftUIViewTests: XCTestCase {
    // MARK: - Properties
    
    @State private var testText = "Hello, World!"
    private var onTextChangeCalled = false
    private var onSelectionChangeCalled = false
    
    // MARK: - Basic Tests
    
    func testSwiftUIViewInitialization() {
        let view = CodeEditorSwiftUIView(
            text: .constant("Test"),
            language: .swift,
            theme: .default,
            configuration: .default
        )
        
        XCTAssertEqual(view.language, .swift)
        XCTAssertEqual(view.theme, .default)
        XCTAssertEqual(view.configuration, .default)
    }
    
    func testLegacyInitializer() {
        let view = CodeEditorSwiftUIView(
            text: .constant("Test"),
            showLineNumbers: true,
            highlightSelectedLine: false,
            isEditable: true,
            language: .python
        )
        
        XCTAssertEqual(view.language, .python)
        XCTAssertTrue(view.configuration.display.showLineNumbers)
        XCTAssertFalse(view.configuration.display.highlightSelectedLine)
        XCTAssertTrue(view.configuration.behavior.isEditable)
    }
    
    // MARK: - Modifier Tests
    
    func testLanguageModifier() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
            .language(.javascript)
        
        XCTAssertEqual(view.language, .javascript)
    }
    
    func testShowLineNumbersModifier() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
            .showLineNumbers(true)
        
        XCTAssertTrue(view.configuration.display.showLineNumbers)
    }
    
    func testHighlightSelectedLineModifier() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
            .highlightSelectedLine(true)
        
        XCTAssertTrue(view.configuration.display.highlightSelectedLine)
    }
    
    func testEditableModifier() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
            .editable(false)
        
        XCTAssertFalse(view.configuration.behavior.isEditable)
    }
    
    func testShowMinimapModifier() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
            .showMinimap(true)
        
        XCTAssertTrue(view.configuration.display.showMinimap)
    }
    
    func testChainedModifiers() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
            .language(.swift)
            .showLineNumbers(true)
            .highlightSelectedLine(true)
            .editable(true)
            .showMinimap(false)
        
        XCTAssertEqual(view.language, .swift)
        XCTAssertTrue(view.configuration.display.showLineNumbers)
        XCTAssertTrue(view.configuration.display.highlightSelectedLine)
        XCTAssertTrue(view.configuration.behavior.isEditable)
        XCTAssertFalse(view.configuration.display.showMinimap)
    }
    
    // MARK: - Callback Tests
    
    func testOnTextChangeCallback() {
        var capturedText: String?
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
            .onTextChange { text in
                capturedText = text
            }
        
        XCTAssertNotNil(view.onTextChange)
        
        // Simulate text change
        view.onTextChange?("New Text")
        XCTAssertEqual(capturedText, "New Text")
    }
    
    func testOnSelectionChangeCallback() {
        var capturedRange: NSRange?
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
            .onSelectionChange { range in
                capturedRange = range
            }
        
        XCTAssertNotNil(view.onSelectionChange)
        
        // Simulate selection change
        let testRange = NSRange(location: 0, length: 4)
        view.onSelectionChange?(testRange)
        XCTAssertEqual(capturedRange?.location, 0)
        XCTAssertEqual(capturedRange?.length, 4)
    }
    
    // MARK: - Platform-Specific Tests
    
    #if os(macOS)
    func testMacOSViewCreation() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
        let coordinator = view.makeCoordinator()
        
        // We can't directly test view creation without SwiftUI context
        XCTAssertNotNil(coordinator)
        XCTAssertTrue(coordinator is CodeEditorSwiftUIView.Coordinator)
    }
    
    func testMacOSMinimapSetup() {
        var config = EditorConfiguration.default
        config.display.showMinimap = true
        
        let view = CodeEditorSwiftUIView(
            text: .constant("Test"),
            configuration: config
        )
        
        let coordinator = view.makeCoordinator()
        XCTAssertNotNil(coordinator)
    }
    #endif
    
    #if os(iOS)
    func testIOSViewCreation() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
        let coordinator = view.makeCoordinator()
        
        // We can't directly test view creation without SwiftUI context
        XCTAssertNotNil(coordinator)
        XCTAssertTrue(coordinator is CodeEditorSwiftUIView.Coordinator)
    }
    
    func testIOSBecomeFirstResponder() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
            .becomeFirstResponder(true)
        
        // This modifier sets an environment value
        // We can't easily test the actual behavior without a full SwiftUI context
        XCTAssertNotNil(view)
    }
    #endif
    
    // MARK: - Theme Tests
    
    func testDefaultTheme() {
        let theme = CodeEditorSwiftUITheme.default
        XCTAssertEqual(theme.name, "default")
    }
    
    func testDarkTheme() {
        let theme = CodeEditorSwiftUITheme.dark
        XCTAssertEqual(theme.name, "dark")
    }
    
    func testCustomTheme() {
        let theme = CodeEditorSwiftUITheme(
            name: "custom",
            backgroundColor: .red,
            textColor: .white,
            lineNumberColor: .gray,
            selectedLineColor: .blue
        )
        
        XCTAssertEqual(theme.name, "custom")
        XCTAssertEqual(theme.backgroundColor, .red)
        XCTAssertEqual(theme.textColor, .white)
    }
    
    func testThemeEquality() {
        let theme1 = CodeEditorSwiftUITheme(name: "test")
        let theme2 = CodeEditorSwiftUITheme(name: "test")
        let theme3 = CodeEditorSwiftUITheme(name: "other")
        
        XCTAssertEqual(theme1, theme2)
        XCTAssertNotEqual(theme1, theme3)
    }
    
    // MARK: - Environment Tests
    
    func testEnvironmentModifiers() {
        let view = Text("Test")
            .codeEditorTheme(.dark)
            .codeEditorBecomeFirstResponder(false)
        
        XCTAssertNotNil(view)
    }
    
    // MARK: - Configuration Builder Tests
    
    func testConfigurationBuilder() {
        let config = ConfigurationBuilder.build(
            showLineNumbers: false,
            highlightSelectedLine: true,
            isEditable: false,
            showMinimap: true,
            fontSize: 16.0
        )
        
        XCTAssertFalse(config.display.showLineNumbers)
        XCTAssertTrue(config.display.highlightSelectedLine)
        XCTAssertFalse(config.behavior.isEditable)
        XCTAssertTrue(config.display.showMinimap)
        XCTAssertEqual(config.display.fontSize, 16.0)
    }
    
    // MARK: - Coordinator Tests
    
    func testCoordinatorStateTracking() {
        let view = CodeEditorSwiftUIView(text: .constant("Test"))
        let coordinator = view.makeCoordinator()
        
        // Initialize state
        coordinator.updateState(
            text: "Test",
            language: .plainText,
            configuration: .default
        )
        
        // Test initial state
        XCTAssertFalse(coordinator.shouldUpdate(
            text: "Test",
            language: .plainText,
            configuration: .default
        ))
        
        // Test state change detection
        XCTAssertTrue(coordinator.shouldUpdate(
            text: "Different",
            language: .plainText,
            configuration: .default
        ))
        
        XCTAssertTrue(coordinator.shouldUpdate(
            text: "Test",
            language: .swift,
            configuration: .default
        ))
        
        var newConfig = EditorConfiguration.default
        newConfig.display.fontSize = 20
        XCTAssertTrue(coordinator.shouldUpdate(
            text: "Test",
            language: .plainText,
            configuration: newConfig
        ))
    }
    
    // MARK: - Performance Tests
    
    func testViewCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = CodeEditorSwiftUIView(
                    text: .constant("Test"),
                    language: .swift,
                    theme: .default,
                    configuration: .default
                )
            }
        }
    }
    
    func testModifierChainPerformance() {
        measure {
            for _ in 0..<100 {
                _ = CodeEditorSwiftUIView(text: .constant("Test"))
                    .language(.swift)
                    .showLineNumbers(true)
                    .highlightSelectedLine(true)
                    .editable(true)
                    .showMinimap(false)
                    .onTextChange { _ in }
                    .onSelectionChange { _ in }
            }
        }
    }
    
    deinit {
        // Cleanup
    }
}
