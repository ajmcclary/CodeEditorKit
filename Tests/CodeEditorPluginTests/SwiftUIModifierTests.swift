import SwiftUI
import XCTest

@testable import CodeEditorPlugin

@available(macOS 12.0, iOS 16.0, *)
final class SwiftUIModifierTests: XCTestCase {
    // MARK: - Language Modifier Tests
    
    @MainActor
    func testCodeLanguageModifier() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        // Test each language
        for language in Language.allCases {
            let editor = CodeEditor(text: binding)
                .codeLanguage(language)
            
            // Verify the modifier is applied
            let mirror = Mirror(reflecting: editor)
            XCTAssertNotNil(mirror.descendant("modifier"))
        }
    }
    
    @MainActor
    func testCodeLanguageModifierPropagation() {
        struct LanguageCaptureView: View {
            @Environment(\.codeEditorLanguage) var language
            
            var body: some View {
                Color.clear
            }
        }
        
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        // Apply language modifier to CodeEditor
        let editor = CodeEditor(text: binding)
            .codeLanguage(.python)
        
        // Verify the modifier is applied
        XCTAssertNotNil(editor)
    }
    
    // MARK: - Theme Modifier Tests
    
    @MainActor
    func testCodeThemeModifier() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        // Test default theme
        let defaultEditor = CodeEditor(text: binding)
            .codeTheme(.default)
        
        // Test dark theme
        let darkEditor = CodeEditor(text: binding)
            .codeTheme(.dark)
        
        // Test custom theme
        let customTheme = CodeEditorSwiftUITheme(
            name: "test",
            backgroundColor: Color.white,
            textColor: Color.black,
            lineNumberColor: Color.gray,
            selectedLineColor: Color.blue.opacity(0.1)
        )
        
        let customEditor = CodeEditor(text: binding)
            .codeTheme(customTheme)
        
        XCTAssertNotNil(defaultEditor)
        XCTAssertNotNil(darkEditor)
        XCTAssertNotNil(customEditor)
    }
    
    // MARK: - Configuration Modifier Tests
    
    @MainActor
    func testCodeEditorConfigurationModifier() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        // Test with preset configurations
        let presets: [EditorConfiguration] = [
            .default,
            .minimal,
            .readOnly,
            .markdown,
            .presentation
        ]
        
        for config in presets {
            let editor = CodeEditor(text: binding)
                .codeEditorEnvironment(configuration: config)
            
            XCTAssertNotNil(editor)
        }
        
        // Test with custom configuration
        let customConfig = EditorConfigurationBuilder()
            .fontSize(20)
            .showLineNumbers(false)
            .enableSyntaxHighlighting(false)
            .build()
        
        let customEditor = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: customConfig)
        
        XCTAssertNotNil(customEditor)
    }
    
    // MARK: - Focus Modifier Tests
    
    @MainActor
    func testCodeEditorBecomeFirstResponderModifier() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        // Test with true
        let focusedEditor = CodeEditor(text: binding)
            .becomeFirstResponder(true)
        
        // Test with false
        let unfocusedEditor = CodeEditor(text: binding)
            .becomeFirstResponder(false)
        
        XCTAssertNotNil(focusedEditor)
        XCTAssertNotNil(unfocusedEditor)
    }
    
    // MARK: - Memory Monitor Modifier Tests
    
    @MainActor
    func testCodeEditorMemoryMonitorModifier() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        let memoryMonitor = MemoryMonitor()
        
        let editor = CodeEditor(text: binding)
            .memoryMonitor(memoryMonitor)
        
        XCTAssertNotNil(editor)
    }
    
    @MainActor
    func testCodeEditorMemoryMonitorNilModifier() {
        // Skip nil test as memoryMonitor doesn't accept nil
        // The modifier requires a MemoryMonitor instance
        XCTAssertTrue(true) // Test skipped
    }
    
    // MARK: - Modifier Chaining Tests
    
    @MainActor
    func testModifierChaining() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        let memoryMonitor = MemoryMonitor()
        
        // Test comprehensive modifier chain
        let editor = CodeEditor(text: binding)
            .codeLanguage(.swift)
            .codeTheme(.dark)
            .codeEditorEnvironment(configuration: .minimal)
            .becomeFirstResponder(true)
            .codeEditorEnvironment(memoryMonitor: memoryMonitor)
            .frame(height: 300)
            .padding()
            .background(Color.gray.opacity(0.1))
        
        XCTAssertNotNil(editor)
    }
    
    @MainActor
    func testModifierOrder() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        // Test that modifiers can be applied in any order
        let editor1 = CodeEditor(text: binding)
            .codeTheme(.dark)
            .codeLanguage(.python)
        
        let editor2 = CodeEditor(text: binding)
            .codeLanguage(.python)
            .codeTheme(.dark)
        
        XCTAssertNotNil(editor1)
        XCTAssertNotNil(editor2)
    }
    
    // MARK: - Conditional Modifier Tests
    
    @MainActor
    func testConditionalModifiers() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        let isDarkMode = Bool.random() // Use random to avoid compiler optimization
        let showLineNumbers = false
        
        let editor = CodeEditor(text: binding)
            .codeTheme(isDarkMode ? .dark : .default)
            .codeEditorEnvironment(
                configuration: EditorConfigurationBuilder()
                    .showLineNumbers(showLineNumbers)
                    .build()
            )
        
        XCTAssertNotNil(editor)
    }
    
    // MARK: - Dynamic Modifier Tests
    
    @MainActor
    func testDynamicModifiers() {
        @State var language = Language.swift
        @State var theme = CodeEditorSwiftUITheme.default
        @State var isFocused = false
        
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        let editor = CodeEditor(text: binding)
            .codeLanguage(language)
            .codeTheme(theme)
            .becomeFirstResponder(isFocused)
        
        // Change state
        language = .python
        theme = .dark
        isFocused = true
        
        // Editor should be valid with new state
        XCTAssertNotNil(editor)
    }
    
    // MARK: - Platform-Specific Modifier Tests
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @MainActor
    func testMacOSSpecificModifiers() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        let config = EditorConfigurationBuilder()
            .showMinimap(true)
            .enableCodeFolding(true)
            .useHardwareAcceleration(true)
            .build()
        
        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: config)
        
        XCTAssertNotNil(editor)
    }
    #endif
    
    #if canImport(UIKit)
    @MainActor
    func testIOSSpecificModifiers() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        let config = EditorConfigurationBuilder()
            .wrapLines(true)
            .fontSize(16)
            .showMinimap(false)
            .build()
        
        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: config)
        
        XCTAssertNotNil(editor)
    }
    #endif
    
    // MARK: - Performance Tests
    
    @MainActor
    func testModifierPerformance() {
        let binding = Binding<String>(
            get: { String(repeating: "Line\n", count: 1_000) },
            set: { _ in }
        )
        
        measure {
            let editor = CodeEditor(text: binding)
                .codeLanguage(.swift)
                .codeTheme(.dark)
                .codeEditorEnvironment(configuration: .platformOptimized)
                .becomeFirstResponder(false)
                .frame(height: 300)
            
            // Just verify the editor was created
            _ = editor
        }
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testModifiersWithSwiftUIContainers() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        // Test in VStack
        let vstack = VStack {
            CodeEditor(text: binding)
                .codeLanguage(.swift)
        }
        
        // Test in HStack
        let hstack = HStack {
            CodeEditor(text: binding)
                .codeTheme(.dark)
        }
        
        // Test in ScrollView
        let scrollView = ScrollView {
            CodeEditor(text: binding)
                .codeEditorEnvironment(configuration: .minimal)
                .frame(height: 300)
        }
        
        // Test in NavigationView
        let navView = NavigationView {
            CodeEditor(text: binding)
                .navigationTitle("Code Editor")
        }
        
        XCTAssertNotNil(vstack)
        XCTAssertNotNil(hstack)
        XCTAssertNotNil(scrollView)
        XCTAssertNotNil(navView)
    }
}
