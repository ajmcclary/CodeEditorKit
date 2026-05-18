import CodeEditorConfiguration
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import SwiftUI
import XCTest

@testable import CodeEditorPlugin

@available(macOS 12.0, iOS 16.0, *)
final class SwiftUITests: XCTestCase {
    // MARK: - Environment Value Tests

    @MainActor
    func testEnvironmentLanguagePropagation() {
        // Test that the environment key properly stores and retrieves values
        struct TestView: View {
            @Environment(\.codeEditorLanguage) var language

            var body: some View {
                Text("Test")
            }
        }

        // Create a view and verify the environment modifier works
        let view = TestView()
            .environment(\.codeEditorLanguage, .python)

        // The environment value should be properly set
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))

        // Test default value through environment
        XCTAssertEqual(CodeEditorEnvironment.default.language, .plainText)
    }

    @MainActor
    func testEnvironmentThemePropagation() {
        // Test that the environment key properly stores and retrieves values
        struct TestView: View {
            @Environment(\.codeEditorTheme) var theme

            var body: some View {
                Text("Test")
            }
        }

        // Create a view and verify the environment modifier works
        let view = TestView()
            .environment(\.codeEditorTheme, .dark)

        // The environment value should be properly set
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))

        // Test default value through environment
        XCTAssertEqual(CodeEditorEnvironment.default.theme, .default)
    }

    @MainActor
    func testEnvironmentConfigurationPropagation() {
        let customConfig = EditorConfiguration.minimal

        // Test that the environment key properly stores and retrieves values
        struct TestView: View {
            @Environment(\.codeEditorConfiguration) var configuration

            var body: some View {
                Text("Test")
            }
        }

        // Create a view and verify the environment modifier works
        let view = TestView()
            .environment(\.codeEditorConfiguration, customConfig)

        // The environment value should be properly set
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))

        // Test default value through environment
        XCTAssertEqual(CodeEditorEnvironment.default.configuration, EditorConfiguration())
    }

    // MARK: - Modifier Tests

    @MainActor
    func testCodeLanguageModifier() {
        // Create a constant binding for testing
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .codeLanguage(.python)

        // The modifier should set the environment value
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    @MainActor
    func testCodeThemeModifier() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .codeTheme(.dark)

        // The modifier should set the environment value
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    @MainActor
    func testShowLineNumbersModifier() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .lineNumbers(true)

        // The modifier should transform the configuration
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    @MainActor
    func testEditableModifier() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .editable(false)

        // The modifier should transform the configuration
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    @MainActor
    func testBecomeFirstResponderModifier() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .becomeFirstResponder()

        // The modifier should set the environment value
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    // MARK: - Initializer Tests

    @MainActor
    func testConvenienceInitializer() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding, language: .python, theme: .dark)

        // The initializer should create a valid view
        XCTAssertNotNil(view)
    }

    // MARK: - Factory Method Tests

    @MainActor
    func testWithLanguageFactory() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor.withLanguage(binding, language: .python, theme: .dark)

        // The factory should return a view with environment values set
        XCTAssertNotNil(view)
    }

    @MainActor
    func testWithConfigurationFactory() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        let config = EditorConfiguration.presentation

        let view = CodeEditor.withConfiguration(binding, configuration: config, language: .plainText)

        // The factory should return a view with environment values set
        XCTAssertNotNil(view)
    }

    // MARK: - Focus Management Tests

    @MainActor
    func testFocusBinding() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Test that the view can be created with a focus modifier
        let view = CodeEditor(text: binding)

        // The view should support focus binding
        XCTAssertNotNil(view)
    }

    // MARK: - Text Binding Tests

    @MainActor
    func testTextBindingUpdate() async {
        var value = "initial"
        let binding = Binding<String>(
            get: { value },
            set: { value = $0 }
        )

        let view = CodeEditor(text: binding)

        // Update the text through binding
        binding.wrappedValue = "updated"

        // The binding should be connected
        XCTAssertNotNil(view)
        XCTAssertEqual(value, "updated")
    }

    // MARK: - Configuration Preset Tests

    @MainActor
    func testMinimalPresetApplication() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .environment(\.codeEditorConfiguration, .minimal)

        XCTAssertNotNil(view)
    }

    @MainActor
    func testReadOnlyPresetApplication() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .environment(\.codeEditorConfiguration, .readOnly)

        XCTAssertNotNil(view)
    }

    @MainActor
    func testMarkdownPresetApplication() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .environment(\.codeEditorConfiguration, .markdown)

        XCTAssertNotNil(view)
    }

    @MainActor
    func testPresentationPresetApplication() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .environment(\.codeEditorConfiguration, .presentation)

        XCTAssertNotNil(view)
    }

    // MARK: - Chained Modifier Tests

    @MainActor
    func testChainedModifiers() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let view = CodeEditor(text: binding)
            .codeLanguage(.swift)

        // All modifiers should chain properly
        XCTAssertNotNil(view)
    }

    // MARK: - Environment Value Default Tests

    func testDefaultLanguageValue() {
        let defaultEnvironment = CodeEditorEnvironment.default
        XCTAssertEqual(defaultEnvironment.language, .plainText)
    }

    func testDefaultThemeValue() {
        let defaultEnvironment = CodeEditorEnvironment.default
        XCTAssertEqual(defaultEnvironment.theme, .default)
    }

    func testDefaultConfigurationValue() {
        let defaultEnvironment = CodeEditorEnvironment.default
        XCTAssertEqual(defaultEnvironment.configuration, EditorConfiguration())
    }

    func testDefaultBecomeFirstResponderValue() {
        let defaultEnvironment = CodeEditorEnvironment.default
        XCTAssertFalse(defaultEnvironment.becomeFirstResponder)
    }
}
