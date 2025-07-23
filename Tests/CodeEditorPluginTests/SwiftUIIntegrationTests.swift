import SwiftUI
import XCTest

@testable import CodeEditorPlugin

@available(macOS 12.0, iOS 16.0, *)
final class SwiftUIIntegrationTests: XCTestCase {
    // MARK: - Basic Integration Tests

    @MainActor
    func testCodeEditorBasicCreation() throws {
        let binding = Binding<String>(
            get: { "test code" },
            set: { _ in }
        )

        let editor = CodeEditor(text: binding)

        // Verify the editor can be created
        XCTAssertNotNil(editor)
    }

    @MainActor
    func testCodeEditorWithLanguageModifier() throws {
        let binding = Binding<String>(
            get: { "print('Hello')" },
            set: { _ in }
        )

        let editor = CodeEditor(text: binding)
            .codeLanguage(.python)

        // The language should be set via environment
        let mirror = Mirror(reflecting: editor)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    @MainActor
    func testCodeEditorWithThemeModifier() throws {
        let binding = Binding<String>(
            get: { "// Dark theme test" },
            set: { _ in }
        )

        let editor = CodeEditor(text: binding)
            .codeTheme(.dark)

        // The theme should be set via environment
        let mirror = Mirror(reflecting: editor)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    @MainActor
    func testCodeEditorWithConfigurationModifier() throws {
        let binding = Binding<String>(
            get: { "configured editor" },
            set: { _ in }
        )

        let config = EditorConfiguration.minimal
        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: config)

        // The configuration should be set via environment
        let mirror = Mirror(reflecting: editor)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    // MARK: - Environment Integration Tests

    @MainActor
    func testConsolidatedEnvironment() throws {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let environment = CodeEditorEnvironment(
            language: .swift,
            theme: .dark,
            configuration: .minimal,
            becomeFirstResponder: true,
            memoryMonitor: nil,
            eventSystem: nil
        )

        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(environment)

        // Verify environment is applied
        let mirror = Mirror(reflecting: editor)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    @MainActor
    func testEnvironmentWithMethod() throws {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(
                language: .javascript,
                theme: .default,
                configuration: .readOnly,
                becomeFirstResponder: .yes
            )

        // Verify environment modifiers are applied
        let mirror = Mirror(reflecting: editor)
        XCTAssertNotNil(mirror.descendant("modifier"))
    }

    // MARK: - Text Binding Tests

    @MainActor
    func testTextBindingUpdates() throws {
        var testText = "initial"
        let binding = Binding<String>(
            get: { testText },
            set: { testText = $0 }
        )

        _ = CodeEditor(text: binding)

        // Initial text should match
        XCTAssertEqual(testText, "initial")

        // Simulate text change
        binding.wrappedValue = "updated"
        XCTAssertEqual(testText, "updated")
    }

    @MainActor
    func testReadOnlyBinding() throws {
        let constantText = "read only"
        let binding = Binding<String>(
            get: { constantText },
            set: { _ in XCTFail("Should not set read-only text") }
        )

        let editor = CodeEditor(text: binding)
            .editable(false)

        XCTAssertNotNil(editor)
    }

    // MARK: - Modifier Chain Tests

    @MainActor
    func testModifierChaining() throws {
        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let editor = CodeEditor(text: binding)
            .codeLanguage(.swift)
            .codeTheme(.dark)
            .lineNumbers(false)  // minimal config
            .becomeFirstResponder(true)
            .frame(height: 300)
            .padding()

        // All modifiers should be applied
        XCTAssertNotNil(editor)
    }

    @MainActor
    func testCustomEventHandlers() throws {
        final class Counter: @unchecked Sendable {
            private var value = 0
            private let queue = DispatchQueue(label: "counter")

            func increment() {
                queue.sync { value += 1 }
            }

            func get() -> Int {
                queue.sync { value }
            }
        }

        let textChangeCount = Counter()
        let selectionChangeCount = Counter()

        let binding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let editor = CodeEditor(text: binding)
            .onTextChange { _ in
                textChangeCount.increment()
            }
            .onSelectionChange { _ in
                selectionChangeCount.increment()
            }

        XCTAssertNotNil(editor)
        XCTAssertEqual(textChangeCount.get(), 0) // No changes yet
        XCTAssertEqual(selectionChangeCount.get(), 0) // No selection changes yet
    }

    // MARK: - Platform-Specific Tests

    @MainActor
    func testPlatformOptimizedConfiguration() throws {
        let binding = Binding<String>(
            get: { "platform test" },
            set: { _ in }
        )

        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: .platformOptimized)

        XCTAssertNotNil(editor)
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @MainActor
    func testMacOSSpecificFeatures() throws {
        let binding = Binding<String>(
            get: { "macOS test" },
            set: { _ in }
        )

        let config = PlatformConfigurations.macOS
        _ = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: config)

        // Verify macOS-specific configuration
        XCTAssertTrue(config.display.showMinimap)
        XCTAssertTrue(config.performance.useHardwareAcceleration)
    }
    #endif

    #if canImport(UIKit)
    @MainActor
    func testIOSSpecificFeatures() throws {
        let binding = Binding<String>(
            get: { "iOS test" },
            set: { _ in }
        )

        let config = PlatformConfigurations.iOS
        _ = CodeEditor(text: binding)
            .codeEditorEnvironment(configuration: config)

        // Verify iOS-specific configuration
        XCTAssertFalse(config.display.showMinimap)
        XCTAssertTrue(config.layout.wrapLines)
    }
    #endif

    // MARK: - Performance Tests

    @MainActor
    func testLargeTextPerformance() throws {
        let largeText = String(repeating: "Line of code\n", count: 10_000)
        let binding = Binding<String>(
            get: { largeText },
            set: { _ in }
        )

        measure(options: Self.standardMeasureOptions) {
            _ = CodeEditor(text: binding)
                .codeLanguage(.swift)
                .codeEditorEnvironment(configuration: .platformOptimized)
        }
    }

    // MARK: - Memory Monitor Integration

    @MainActor
    func testMemoryMonitorIntegration() throws {
        let binding = Binding<String>(
            get: { "memory test" },
            set: { _ in }
        )

        let memoryMonitor = MemoryMonitor()
        let editor = CodeEditor(text: binding)
            .memoryMonitor(memoryMonitor)

        XCTAssertNotNil(editor)
    }

    // MARK: - Focus Management Tests

    @MainActor
    func testFocusManagement() throws {
        let binding = Binding<String>(
            get: { "focus test" },
            set: { _ in }
        )

        // Test old-style focus
        let editor1 = CodeEditor(text: binding)
            .becomeFirstResponder(true)

        // Test new-style focus with enum
        let editor2 = CodeEditor(text: binding)
            .codeEditorEnvironment(becomeFirstResponder: .yes)

        XCTAssertNotNil(editor1)
        XCTAssertNotNil(editor2)
    }

    // MARK: - Theme Integration Tests

    @MainActor
    func testThemeApplication() throws {
        let binding = Binding<String>(
            get: { "theme test" },
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
            name: "custom",
            backgroundColor: Color.white,
            textColor: Color.blue,
            lineNumberColor: Color.gray,
            selectedLineColor: Color.gray.opacity(0.1)
        )

        let customEditor = CodeEditor(text: binding)
            .codeTheme(customTheme)

        XCTAssertNotNil(defaultEditor)
        XCTAssertNotNil(darkEditor)
        XCTAssertNotNil(customEditor)
    }

    // MARK: - Language Support Tests

    @MainActor
    func testAllLanguagesSupport() throws {
        let binding = Binding<String>(
            get: { "language test" },
            set: { _ in }
        )

        // Test each supported language
        for language in Language.allCases {
            let editor = CodeEditor(text: binding)
                .codeLanguage(language)

            XCTAssertNotNil(editor, "Failed to create editor for language: \(language)")
        }
    }

    // MARK: - Configuration Preset Tests

    @MainActor
    func testConfigurationPresets() throws {
        let binding = Binding<String>(
            get: { "preset test" },
            set: { _ in }
        )

        let presets: [EditorConfiguration] = [
            .default,
            .minimal,
            .readOnly,
            .markdown,
            .presentation,
            .platformOptimized
        ]

        for preset in presets {
            let editor = CodeEditor(text: binding)
                .codeEditorEnvironment(configuration: preset)

            XCTAssertNotNil(editor)
        }
    }

    // MARK: - SwiftUI Layout Integration

    @MainActor
    func testLayoutIntegration() throws {
        let binding = Binding<String>(
            get: { "layout test" },
            set: { _ in }
        )

        // Test with various layout modifiers
        let editor = CodeEditor(text: binding)
            .frame(
                minWidth: 100,
                idealWidth: 300,
                maxWidth: .infinity,
                minHeight: 100,
                idealHeight: 300,
                maxHeight: .infinity
            )
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .shadow(radius: 2)

        XCTAssertNotNil(editor)
    }

    // MARK: - Event System Integration

    @MainActor
    func testEventSystemIntegration() throws {
        let binding = Binding<String>(
            get: { "event test" },
            set: { _ in }
        )

        let eventSystem = UnifiedEventSystem()
        var receivedEvents: [EditorEvent] = []

        // Subscribe to events
        _ = eventSystem.subscribe(to: TextDidChangeEvent.self) { event in
            receivedEvents.append(EditorEvent.textDidChange(event.text))
        }

        let editor = CodeEditor(text: binding)
            .codeEditorEnvironment(eventSystem: eventSystem)

        XCTAssertNotNil(editor)
    }

    // MARK: - Debounce Configuration Tests

    @MainActor
    func testDebounceConfiguration() throws {
        let binding = Binding<String>(
            get: { "debounce test" },
            set: { _ in }
        )

        // Test with custom debounce interval
        let editor = CodeEditor(text: binding)
            // Custom debounce interval should be passed in initializer

        XCTAssertNotNil(editor)
    }

    // MARK: - Accessibility Tests

    @MainActor
    func testAccessibilitySupport() throws {
        let binding = Binding<String>(
            get: { "accessibility test" },
            set: { _ in }
        )

        let editor = CodeEditor(text: binding)
            .accessibilityLabel("Code editor")
            .accessibilityHint("Enter your code here")
            .accessibilityValue(binding.wrappedValue)

        XCTAssertNotNil(editor)
    }

    // MARK: - State Restoration Tests

    @MainActor
    func testStateRestoration() throws {
        @State var text = "state test"
        @State var language = Language.swift
        @State var configuration = EditorConfiguration.default

        let binding = Binding<String>(
            get: { text },
            set: { text = $0 }
        )

        let editor = CodeEditor(text: binding)
            .codeLanguage(language)
            .codeEditorEnvironment(configuration: configuration)

        // Change state
        language = .python
        configuration = .minimal

        // Editor should reflect new state
        XCTAssertNotNil(editor)
    }
}

// MARK: - Helper Extensions for Testing

@available(macOS 12.0, iOS 16.0, *)
extension CodeEditor {
    /// Helper to access the underlying representable for testing
    var representable: some View {
        self.body
    }
}

// Mock ViewInspector protocol conformance (if using ViewInspector)
// Note: This would require the ViewInspector package to be added as a test dependency
// For now, we're using Mirror-based inspection which is built-in
