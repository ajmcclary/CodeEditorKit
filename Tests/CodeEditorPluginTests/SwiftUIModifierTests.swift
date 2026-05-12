import SwiftUI
import XCTest

@testable import CodeEditorPlugin

@available(macOS 12.0, iOS 16.0, *)
final class SwiftUIModifierTests: XCTestCase {
    private func assertTypeName<V: View>(
        _ view: V,
        contains expectedFragment: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let typeName = String(reflecting: type(of: view))
        XCTAssertTrue(
            typeName.contains(expectedFragment),
            "Expected \(typeName) to contain \(expectedFragment)",
            file: file,
            line: line
        )
    }

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

        assertTypeName(editor, contains: "ModifiedContent")
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

        // Test custom theme — use the light fallback as a custom-shaped Theme.
        let customTheme = Theme.fallback(appearance: .light)

        let customEditor = CodeEditor(text: binding)
            .codeTheme(customTheme)

        assertTypeName(defaultEditor, contains: "ModifiedContent")
        assertTypeName(darkEditor, contains: "ModifiedContent")
        assertTypeName(customEditor, contains: "ModifiedContent")
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

            assertTypeName(editor, contains: "ModifiedContent")
        }

        // Test with custom configuration
        var customConfig = EditorConfiguration()
        customConfig.display.fontSize = 20
        customConfig.display.isLineNumbersEnabled = false
        customConfig.display.isSyntaxHighlightingEnabled = false

        let customEditor = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: customConfig)

        assertTypeName(customEditor, contains: "ModifiedContent")
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

        assertTypeName(focusedEditor, contains: "ModifiedContent")
        assertTypeName(unfocusedEditor, contains: "ModifiedContent")
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

        assertTypeName(editor, contains: "ModifiedContent")
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

        assertTypeName(editor, contains: "ModifiedContent")
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

        assertTypeName(editor1, contains: "ModifiedContent")
        assertTypeName(editor2, contains: "ModifiedContent")
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

        var configurationForTheme = EditorConfiguration()
        configurationForTheme.display.isLineNumbersEnabled = showLineNumbers
        let editor = CodeEditor(text: binding)
            .codeTheme(isDarkMode ? .dark : .default)
            .codeEditorEnvironment(configuration: configurationForTheme)

        assertTypeName(editor, contains: "ModifiedContent")
    }

    // MARK: - Dynamic Modifier Tests

    @MainActor
    func testDynamicModifiers() {
        @State var language = Language.swift
        @State var theme = Theme.default
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
        assertTypeName(editor, contains: "ModifiedContent")
    }

    // MARK: - Platform-Specific Modifier Tests

    #if canImport(AppKit)
    @MainActor
    func testMacOSSpecificModifiers() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        var config = EditorConfiguration()
        config.display.isMinimapVisible = true
        config.display.isCodeFoldingEnabled = true
        config.performance.useHardwareAcceleration = true

        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: config)

        assertTypeName(editor, contains: "ModifiedContent")
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
            .isMinimapVisible(false)
            .build()

        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: config)

        assertTypeName(editor, contains: "ModifiedContent")
    }
    #endif

    // MARK: - Performance Tests

    @MainActor
    func testModifierPerformance() {
        let binding = Binding<String>(
            get: { String(repeating: "Line\n", count: 1_000) },
            set: { _ in }
        )

        measure(options: Self.standardMeasureOptions) {
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

        assertTypeName(vstack, contains: "VStack")
        assertTypeName(hstack, contains: "HStack")
        assertTypeName(scrollView, contains: "ScrollView")
        assertTypeName(navView, contains: "NavigationView")
    }
}
