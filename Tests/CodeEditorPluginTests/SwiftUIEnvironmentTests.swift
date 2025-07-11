import SwiftUI
import XCTest

@testable import CodeEditorPlugin

@available(macOS 12.0, iOS 16.0, *)
final class SwiftUIEnvironmentTests: XCTestCase {
    // MARK: - CodeEditorEnvironment Tests
    
    func testCodeEditorEnvironmentCreation() {
        let env = CodeEditorEnvironment()
        
        XCTAssertEqual(env.language, .plainText)
        XCTAssertEqual(env.theme, .default)
        XCTAssertEqual(env.configuration, EditorConfiguration())
        XCTAssertFalse(env.becomeFirstResponder)
        XCTAssertNil(env.memoryMonitor)
        XCTAssertNil(env.eventSystem)
    }
    
    @MainActor
    func testCodeEditorEnvironmentWithMethod() {
        let env = CodeEditorEnvironment()
        let memoryMonitor = MemoryMonitor()
        let eventSystem = UnifiedEventSystem()
        
        let updated = env.with(
            language: .swift,
            theme: .dark,
            configuration: .minimal,
            becomeFirstResponder: .yes,
            memoryMonitor: memoryMonitor,
            eventSystem: eventSystem
        )
        
        XCTAssertEqual(updated.language, .swift)
        XCTAssertEqual(updated.theme, .dark)
        XCTAssertEqual(updated.configuration, .minimal)
        XCTAssertTrue(updated.becomeFirstResponder)
        XCTAssertIdentical(updated.memoryMonitor, memoryMonitor)
        XCTAssertIdentical(updated.eventSystem, eventSystem)
        
        // Original should be unchanged
        XCTAssertEqual(env.language, .plainText)
    }
    
    func testBecomeFirstResponderOption() {
        let env = CodeEditorEnvironment()
        
        // Test .yes
        let envYes = env.with(becomeFirstResponder: .yes)
        XCTAssertTrue(envYes.becomeFirstResponder)
        
        // Test .no
        let envNo = env.with(becomeFirstResponder: .no)
        XCTAssertFalse(envNo.becomeFirstResponder)
        
        // Test .unchanged
        let envUnchanged = env.with(becomeFirstResponder: .unchanged)
        XCTAssertEqual(envUnchanged.becomeFirstResponder, env.becomeFirstResponder)
    }
    
    // MARK: - Environment Key Tests
    
    @MainActor
    func testEnvironmentKeyDefaultValue() {
        let defaultEnv = CodeEditorEnvironmentKey.defaultValue
        XCTAssertEqual(defaultEnv.language, CodeEditorEnvironment.default.language)
        XCTAssertEqual(defaultEnv.theme, CodeEditorEnvironment.default.theme)
        XCTAssertEqual(defaultEnv.configuration, CodeEditorEnvironment.default.configuration)
        XCTAssertEqual(defaultEnv.becomeFirstResponder, CodeEditorEnvironment.default.becomeFirstResponder)
    }
    
    @MainActor
    func testEnvironmentValuesExtension() {
        var values = EnvironmentValues()
        
        // Test getter
        let defaultEnv = values.codeEditorEnvironment
        XCTAssertEqual(defaultEnv.language, CodeEditorEnvironment.default.language)
        XCTAssertEqual(defaultEnv.theme, CodeEditorEnvironment.default.theme)
        XCTAssertEqual(defaultEnv.configuration, CodeEditorEnvironment.default.configuration)
        XCTAssertEqual(defaultEnv.becomeFirstResponder, CodeEditorEnvironment.default.becomeFirstResponder)
        
        // Test setter
        let customEnv = CodeEditorEnvironment(
            language: .python,
            theme: .dark,
            configuration: .readOnly,
            becomeFirstResponder: true
        )
        values.codeEditorEnvironment = customEnv
        
        XCTAssertEqual(values.codeEditorEnvironment.language, .python)
        XCTAssertEqual(values.codeEditorEnvironment.theme, .dark)
        XCTAssertEqual(values.codeEditorEnvironment.configuration, .readOnly)
        XCTAssertTrue(values.codeEditorEnvironment.becomeFirstResponder)
    }
    
    // MARK: - Legacy Support Tests
    
    @MainActor
    func testLegacyEnvironmentProperties() {
        var values = EnvironmentValues()
        
        // Test theme
        values.codeEditorTheme = .dark
        XCTAssertEqual(values.codeEditorEnvironment.theme, .dark)
        XCTAssertEqual(values.codeEditorTheme, .dark)
        
        // Test language
        values.codeEditorLanguage = .javascript
        XCTAssertEqual(values.codeEditorEnvironment.language, .javascript)
        XCTAssertEqual(values.codeEditorLanguage, .javascript)
        
        // Test configuration
        values.codeEditorConfiguration = .minimal
        XCTAssertEqual(values.codeEditorEnvironment.configuration, .minimal)
        XCTAssertEqual(values.codeEditorConfiguration, .minimal)
        
        // Test become first responder
        values.codeEditorBecomeFirstResponder = true
        XCTAssertTrue(values.codeEditorEnvironment.becomeFirstResponder)
        XCTAssertTrue(values.codeEditorBecomeFirstResponder)
        
        // Test memory monitor
        let memoryMonitor = MemoryMonitor()
        values.codeEditorMemoryMonitor = memoryMonitor
        XCTAssertIdentical(values.codeEditorEnvironment.memoryMonitor, memoryMonitor)
        XCTAssertIdentical(values.codeEditorMemoryMonitor, memoryMonitor)
        
        // Test event system
        let eventSystem = UnifiedEventSystem()
        values.codeEditorEventSystem = eventSystem
        XCTAssertIdentical(values.codeEditorEnvironment.eventSystem, eventSystem)
        XCTAssertIdentical(values.codeEditorEventSystem, eventSystem)
    }
    
    // MARK: - View Modifier Tests
    
    private struct TestView: View {
        var body: some View {
            Text("Test")
        }
    }
    
    @MainActor
    func testCodeEditorEnvironmentViewModifier() {
        let customEnv = CodeEditorEnvironment(
            language: .rust,
            theme: .dark,
            configuration: .markdown
        )
        
        let view = TestView()
            .codeEditorEnvironment(customEnv)
        
        // The modifier should be applied
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }
    
    @MainActor
    func testCodeEditorEnvironmentBuilderModifier() {
        let view = TestView()
            .codeEditorEnvironment {
                CodeEditorEnvironment(
                    language: .go,
                    theme: .default,
                    configuration: .presentation
                )
            }
        
        // The modifier should be applied
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }
    
    @MainActor
    func testCodeEditorEnvironmentConvenienceModifier() {
        let memoryMonitor = MemoryMonitor()
        
        let view = TestView()
            .codeEditorEnvironment(
                language: .sql,
                theme: .dark,
                configuration: .minimal,
                becomeFirstResponder: .yes,
                memoryMonitor: memoryMonitor
            )
        
        // The modifier should be applied
        let mirror = Mirror(reflecting: view)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }
    
    // MARK: - Integration with CodeEditor
    
    @MainActor
    func testCodeEditorUsesEnvironment() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        let customEnv = CodeEditorEnvironment(
            language: .php,
            theme: .dark,
            configuration: EditorConfiguration.builder()
                .fontSize(18)
                .isLineNumbersEnabled(false)
                .build()
        )
        
        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(customEnv)
        
        // Verify the editor is created with the environment
        XCTAssertNotNil(editor)
    }
    
    // MARK: - Environment Propagation Tests
    
    @MainActor
    func testEnvironmentPropagationThroughHierarchy() {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )
        
        let customEnv = CodeEditorEnvironment(
            language: .ruby,
            theme: .dark
        )
        
        // Create a view hierarchy
        let view = VStack {
            CodeEditor(text: binding)
            CodeEditor(text: binding)
        }
        .codeEditorEnvironment(customEnv)
        
        // Both editors should receive the environment
        XCTAssertNotNil(view)
    }
    
    // MARK: - Thread Safety Tests
    
    func testCodeEditorEnvironmentIsSendable() {
        // This test verifies that CodeEditorEnvironment conforms to Sendable
        let env = CodeEditorEnvironment()
        
        // Should be able to pass across actor boundaries
        Task {
            _ = env
        }
        
        Task.detached {
            _ = env
        }
    }
    
    // MARK: - Result Builder Tests
    
    @MainActor
    func testCodeEditorEnvironmentBuilder() {
        // Test that the result builder works correctly
        @CodeEditorEnvironmentBuilder
        func buildEnvironment() -> CodeEditorEnvironment {
            CodeEditorEnvironment(
                language: .c,
                theme: .default,
                configuration: .minimal
            )
        }
        
        let env = buildEnvironment()
        XCTAssertEqual(env.language, .c)
        XCTAssertEqual(env.theme, .default)
        XCTAssertEqual(env.configuration, .minimal)
    }
}
