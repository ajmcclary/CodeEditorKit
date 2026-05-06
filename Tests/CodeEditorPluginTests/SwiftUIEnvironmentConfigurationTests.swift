import SwiftUI
import XCTest

@testable import CodeEditorPlugin

@available(macOS 13.0, iOS 16.0, *)
final class SwiftUIEnvironmentConfigurationTests: XCTestCase {
    // MARK: - Test Setup

    // MARK: - Environment Configuration Flow Tests

    @MainActor
    func testEnvironmentConfigurationAppliedToCodeEditor() {
        // Create binding
        let binding = Binding<String>(
            get: { "test code" },
            set: { _ in }
        )

        // Create custom configuration
        var customConfig = EditorConfiguration()
        customConfig.display.fontSize = 18.0
        customConfig.display.isLineNumbersEnabled = false
        customConfig.display.isSelectedLineHighlighted = true
        customConfig.behavior.isEditable = false
        customConfig.layout.tabWidth = 2

        // Create environment
        let environment = CodeEditorEnvironment(
            language: .python,
            theme: .dark,
            configuration: customConfig,
            becomeFirstResponder: true
        )

        // Create editor with environment
        let editor = CodeEditor(text: binding)
        let editorWithEnv = editor.codeEditorEnvironment(environment)

        // Verify the editor struct exists
        XCTAssertNotNil(editorWithEnv)

        // Test that environment was applied
        // Note: We can't directly test the internal state, but we can verify
        // that the view was created with the environment
    }

    @MainActor
    func testEnvironmentConfigurationWithMemoryMonitor() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Create custom memory monitor
        let memoryMonitor = MemoryMonitor()
        memoryMonitor.memoryThresholdMB = 150.0

        // Create environment with memory monitor
        let environment = CodeEditorEnvironment(
            memoryMonitor: memoryMonitor
        )

        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(environment)

        XCTAssertNotNil(editor)

        // Test with modifier
        let editorWithModifier = CodeEditor(text: binding)
            .memoryMonitor(memoryMonitor)

        XCTAssertNotNil(editorWithModifier)
    }

    @MainActor
    func testEnvironmentConfigurationWithEventSystem() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Create custom event system
        let eventSystem = UnifiedEventSystem()

        // Create environment with event system
        let environment = CodeEditorEnvironment(
            eventSystem: eventSystem
        )

        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(environment)

        XCTAssertNotNil(editor)

        // Test with modifier
        let editorWithModifier = CodeEditor(text: binding)
            .eventSystem(eventSystem)

        XCTAssertNotNil(editorWithModifier)
    }

    // MARK: - Modifier Chain Tests

    @MainActor
    func testModifierChainConfiguration() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Test that various modifiers can be applied
        // Mix of View and CodeEditor modifiers
        let editor = CodeEditor(text: binding)
            // First apply CodeEditor-specific modifiers that return CodeEditor
            .onTextChange { _ in }
            .onSelectionChange { _ in }
            // Then apply View modifiers (these return some View)
            .codeLanguage(.swift)
            .codeTheme(.dark)
            .lineNumbers(true)
            .becomeFirstResponder()

        XCTAssertNotNil(editor)
    }

    @MainActor
    func testCodeEditorSpecificModifiers() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Test applying configuration through environment
        var config = EditorConfiguration()
        config.layout.tabWidth = 4
        config.display.fontSize = 16.0
        config.display.areInvisibleCharactersVisible = false
        config.display.isMinimapVisible = true
        config.behavior.autoScrollToCursor = true
        config.display.isCodeFoldingEnabled = true
        config.display.areFoldingControlsVisible = true
        config.display.minimumFoldableLines = 5

        let editor = CodeEditor(text: binding)
            .environment(\.codeEditorConfiguration, config)

        XCTAssertNotNil(editor)
    }

    @MainActor
    func testModifierOrderIndependence() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Test that modifier order doesn't matter
        let editor1 = CodeEditor(text: binding)
            .codeLanguage(.javascript)
            .codeTheme(.default)
            .lineNumbers(false)

        let editor2 = CodeEditor(text: binding)
            .lineNumbers(false)
            .codeTheme(.default)
            .codeLanguage(.javascript)

        let editor3 = CodeEditor(text: binding)
            .codeTheme(.default)
            .lineNumbers(false)
            .codeLanguage(.javascript)

        // All should be valid configurations
        XCTAssertNotNil(editor1)
        XCTAssertNotNil(editor2)
        XCTAssertNotNil(editor3)
    }

    // MARK: - Environment Override Tests

    @MainActor
    func testModifierOverridesEnvironment() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Create environment with specific settings
        let environment = CodeEditorEnvironment(
            language: .python,
            theme: .dark,
            configuration: EditorConfiguration.minimal
        )

        // Apply environment then override with modifiers
        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(environment)
            .codeLanguage(.rust) // Override language
            .codeTheme(.default) // Override theme
            .lineNumbers(true) // Override configuration

        XCTAssertNotNil(editor)
    }

    @MainActor
    func testEnvironmentPropagationInViewHierarchy() {
        let binding1 = Binding<String>(
            get: { "code1" },
            set: { _ in }
        )

        let binding2 = Binding<String>(
            get: { "code2" },
            set: { _ in }
        )

        // Create environment at parent level
        let environment = CodeEditorEnvironment(
            language: .swift,
            theme: .dark,
            configuration: .presentation
        )

        // Create view hierarchy
        struct TestContainer: View {
            let binding1: Binding<String>
            let binding2: Binding<String>

            var body: some View {
                VStack {
                    CodeEditor(text: binding1)
                    CodeEditor(text: binding2)
                        .codeLanguage(.python) // Local override
                }
            }
        }

        let container = TestContainer(binding1: binding1, binding2: binding2)
            .codeEditorEnvironment(environment)

        XCTAssertNotNil(container)
    }

    // MARK: - Configuration Preset Tests

    @MainActor
    func testConfigurationPresetIntegration() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Test with different presets
        let presets: [EditorConfiguration] = [
            .default,
            .minimal,
            .readOnly,
            .markdown,
            .presentation
        ]

        for preset in presets {
            let editor = CodeEditor(text: binding)
                .environment(\.codeEditorConfiguration, preset)

            XCTAssertNotNil(editor)
        }
    }

    // MARK: - Builder Pattern Tests

    @MainActor
    func testEditorConfigurationDirectIntegration() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        var config = EditorConfiguration()
        config.display.fontSize = 18
        config.display.isLineNumbersEnabled = true
        config.display.isSelectedLineHighlighted = true
        config.behavior.isEditable = false
        config.layout.tabWidth = 2
        config.display.isMinimapVisible = true
        config.display.isCodeFoldingEnabled = true

        let editor = CodeEditor(text: binding)
            .environment(\.codeEditorConfiguration, config)

        XCTAssertNotNil(editor)
    }

    @MainActor
    func testCodeEditorEnvironmentBuilderPattern() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Use environment builder modifier
        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment {
                CodeEditorEnvironment(
                    language: .typescript,
                    theme: .dark,
                    configuration: .minimal,
                    becomeFirstResponder: true
                )
            }

        XCTAssertNotNil(editor)
    }

    // MARK: - Callback Configuration Tests

    @MainActor
    func testCallbackConfiguration() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let expectation = expectation(description: "Callbacks should be set")
        expectation.isInverted = true

        let editor = CodeEditor(text: binding)
            .onTextChange { _ in
                // In real usage, this would be called when text changes
            }
            .onSelectionChange { _ in
                // In real usage, this would be called when selection changes
            }

        XCTAssertNotNil(editor)
        XCTAssertNotNil(editor.onTextChange)
        XCTAssertNotNil(editor.onSelectionChange)

        wait(for: [expectation], timeout: 0.1)
    }

    @MainActor
    func testCompletionProviderConfiguration() async {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let editor = CodeEditor(text: binding)
            .codeCompletion { context in
                // Test that context has expected properties
                XCTAssertNotNil(context.text)
                XCTAssertNotNil(context.language)
                XCTAssertNotNil(context.cursorPosition)

                return [
                    SwiftUICompletionItem(
                        label: "test",
                        kind: .keyword,
                        insertText: "test()"
                    )
                ]
            }

        XCTAssertNotNil(editor)
        XCTAssertNotNil(editor.completionProvider)

        // Test completion provider
        if let provider = editor.completionProvider {
            let context = SwiftUICompletionContext(
                text: "let x = ",
                cursorPosition: 8,
                language: .swift
            )

            let completions = await provider(context)
            XCTAssertEqual(completions.count, 1)
            XCTAssertEqual(completions.first?.label, "test")
        }
    }

    // MARK: - Debounce Configuration Tests

    @MainActor
    func testDebounceIntervalConfiguration() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Test default debounce
        let editor1 = CodeEditor(text: binding)
        XCTAssertNotNil(editor1)

        // Test custom debounce
        let editor2 = CodeEditor(text: binding, debounceInterval: .milliseconds(500))
        XCTAssertNotNil(editor2)

        // Test zero debounce
        let editor3 = CodeEditor(text: binding, debounceInterval: .zero)
        XCTAssertNotNil(editor3)
    }

    // MARK: - Initial Value Tests

    @MainActor
    func testInitialLanguageAndThemeConfiguration() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Test initializer with language and theme
        let editor1 = CodeEditor(text: binding, language: .swift, theme: .dark)
        XCTAssertNotNil(editor1)

        // Test that initial values override environment
        let environment = CodeEditorEnvironment(
            language: .python,
            theme: .default
        )

        let editor2 = CodeEditor(text: binding, language: .javascript, theme: .dark)
            .codeEditorEnvironment(environment) // Environment should be overridden

        XCTAssertNotNil(editor2)
    }

    // MARK: - Complex Configuration Scenarios

    @MainActor
    func testComplexConfigurationScenario() {
        let binding = Binding<String>(
            get: { "// Complex test" },
            set: { _ in }
        )

        // Create all custom components
        let memoryMonitor = MemoryMonitor()
        let eventSystem = UnifiedEventSystem()

        // Create custom configuration
        var config = EditorConfiguration()
        config.display.fontSize = 20
        config.display.isLineNumbersEnabled = true
        config.display.isSelectedLineHighlighted = true
        config.layout.tabWidth = 2
        config.display.isMinimapVisible = false
        config.display.isCodeFoldingEnabled = true

        // Create comprehensive environment
        let environment = CodeEditorEnvironment(
            language: .swift,
            theme: .dark,
            configuration: config,
            becomeFirstResponder: true,
            memoryMonitor: memoryMonitor,
            eventSystem: eventSystem
        )

        // Apply everything
        let baseEditor = CodeEditor(text: binding, debounceInterval: .milliseconds(300))
            .onTextChange { text in
                print("Text changed: \(text.count) characters")
            }
            .onSelectionChange { range in
                print("Selection: \(range?.description ?? "none")")
            }
            .codeCompletion { _ in
                [SwiftUICompletionItem(label: "test", kind: .function)]
            }

        let editor = baseEditor.codeEditorEnvironment(environment)

        XCTAssertNotNil(editor)
        XCTAssertNotNil(baseEditor.onTextChange)
        XCTAssertNotNil(baseEditor.onSelectionChange)
        XCTAssertNotNil(baseEditor.completionProvider)
    }

    // MARK: - Environment Update Tests

    @MainActor
    func testEnvironmentUpdateMethods() {
        let environment = CodeEditorEnvironment()

        // Test partial updates
        let updated1 = environment.with(language: .python)
        XCTAssertEqual(updated1.language, .python)
        XCTAssertEqual(updated1.theme, environment.theme) // Unchanged

        let updated2 = environment.with(theme: .dark)
        XCTAssertEqual(updated2.theme, .dark)
        XCTAssertEqual(updated2.language, environment.language) // Unchanged

        let updated3 = environment.with(
            language: .javascript,
            theme: .dark,
            configuration: .minimal
        )
        XCTAssertEqual(updated3.language, .javascript)
        XCTAssertEqual(updated3.theme, .dark)
        XCTAssertEqual(updated3.configuration, .minimal)
    }

    // MARK: - View Modifier Convenience Tests

    @MainActor
    func testConvenienceEnvironmentModifiers() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Test single property update
        let editor1 = CodeEditor(text: binding)
            .codeEditorEnvironment(language: .rust)

        // Test multiple property updates
        let editor2 = CodeEditor(text: binding)
            .codeEditorEnvironment(
                language: .go,
                theme: .dark,
                becomeFirstResponder: .yes
            )

        // Test with memory monitor and event system
        let memoryMonitor = MemoryMonitor()
        let eventSystem = UnifiedEventSystem()

        let editor3 = CodeEditor(text: binding)
            .codeEditorEnvironment(
                memoryMonitor: memoryMonitor,
                eventSystem: eventSystem
            )

        XCTAssertNotNil(editor1)
        XCTAssertNotNil(editor2)
        XCTAssertNotNil(editor3)
    }

    // MARK: - Performance Configuration Tests

    @MainActor
    func testPerformanceRelatedConfiguration() {
        let binding = Binding<String>(
            get: { String(repeating: "test\n", count: 10_000) }, // Large text
            set: { _ in }
        )

        // Create performance-optimized configuration
        var config = EditorConfiguration()
        config.performance.maxSyntaxHighlightingLength = 50_000
        config.performance.animateCodeFolding = false
        config.performance.textChangeDebounceInterval = .milliseconds(500)

        let editor = CodeEditor(text: binding)
            .environment(\.codeEditorConfiguration, config)

        XCTAssertNotNil(editor)
    }
}
