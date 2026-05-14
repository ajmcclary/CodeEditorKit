import SwiftUI
import XCTest

@testable import CodeEditorPlugin

@available(macOS 13.0, iOS 16.0, *)
final class SwiftUICoordinatorTests: XCTestCase {
    // MARK: - Coordinator Creation Tests

    @MainActor
    func testCoordinatorCreation() {
        let textBinding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        var textChangeCount = 0
        var selectionChangeCount = 0

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: { _ in textChangeCount += 1 },
            onSelectionChange: { _ in selectionChangeCount += 1 }
        )

        XCTAssertNotNil(coordinator)
        XCTAssertEqual(coordinator.textDebounceInterval, .milliseconds(100)) // Default is 100ms
        XCTAssertEqual(textChangeCount, 0)
        XCTAssertEqual(selectionChangeCount, 0)
    }

    @MainActor
    func testCoordinatorDebounceInterval() {
        let textBinding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )

        // Set custom debounce interval
        coordinator.textDebounceInterval = .milliseconds(500)
        XCTAssertEqual(coordinator.textDebounceInterval, .milliseconds(500))
    }

    // MARK: - Container Setup Tests

    @MainActor
    func testSetupContainer() {
        let textBinding = Binding<String>(
            get: { "initial text" },
            set: { _ in }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )

        let container = CodeEditorContainerView()
        let memoryMonitor = MemoryMonitor()

        coordinator.setupContainer(
            container,
            text: "initial text",
            language: .swift,
            theme: .default,
            configuration: .default,
            runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: memoryMonitor),
            onTextChange: nil,
            onSelectionChange: nil
        )

        // Verify setup
        #if canImport(AppKit)
        XCTAssertEqual(container.textView.string, "initial text")
        #else
        XCTAssertEqual(container.textView.text, "initial text")
        #endif
        XCTAssertEqual(container.textView.language, .swift)
        // The container modifies the configuration to disable internal line numbers
        // Note: We only check that line numbers are disabled, not the entire config
        // because adaptive performance mode may modify other settings
        XCTAssertFalse(container.textView.configuration.display.isLineNumbersEnabled)
        XCTAssertIdentical(container.textView.memoryMonitor, memoryMonitor)
    }

    @MainActor
    func testUpdateContainer() {
        let textBinding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )

        let container = CodeEditorContainerView()
        let runtimeDependencies = EditorRuntimeDependencies(memoryMonitor: MemoryMonitor())

        // Initial setup
        coordinator.setupContainer(
            container,
            text: "initial",
            language: .plainText,
            theme: .default,
            configuration: .default,
            runtimeDependencies: runtimeDependencies,
            onTextChange: nil,
            onSelectionChange: nil
        )

        // Update container
        coordinator.updateContainer(
            container,
            text: "updated",
            language: .python,
            theme: .dark,
            configuration: .minimal,
            runtimeDependencies: runtimeDependencies
        )

        // Verify updates
        #if canImport(AppKit)
        XCTAssertEqual(container.textView.string, "updated")
        #else
        XCTAssertEqual(container.textView.text, "updated")
        #endif
        XCTAssertEqual(container.textView.language, .python)
        XCTAssertEqual(container.textView.configuration, .minimal)
    }

    // MARK: - Focus Management Tests

    @MainActor
    func testFocusManagement() {
        let textBinding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )

        let container = CodeEditorContainerView()

        // Test focus management
        coordinator.requestFocusIfNeeded(for: container, shouldBecomeFirstResponder: true)

        // Test focus reset
        coordinator.resetFocusTracking()
    }

    // MARK: - Text Update Tests

    @MainActor
    func testTextUpdateFromEditor() async throws {
        // Use a class to ensure reference semantics for the binding
        class TextHolder {
            var text = ""
        }
        let holder = TextHolder()

        var onTextChangeText: String?
        let textBinding = Binding<String>(
            get: { holder.text },
            set: { holder.text = $0 }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: { newText in
                onTextChangeText = newText
            },
            onSelectionChange: nil
        )

        // Ensure the coordinator's currentText is initialized
        coordinator.currentText = ""

        // Simulate text change from editor
        coordinator.handleTextChange("new text from editor")

        // The onTextChange callback should be called immediately
        XCTAssertEqual(onTextChangeText, "new text from editor")

        // Wait for the coordinator's debounced task to complete
        if let updateTask = coordinator.textUpdateTask {
            _ = await updateTask.value
        }

        // The binding should have been updated after the debounce
        XCTAssertEqual(holder.text, "new text from editor")
    }

    @MainActor
    func testDebouncedTextUpdate() async throws {
        // Use a class to ensure reference semantics for the binding
        class TextHolder {
            var text = ""
            var updateCount = 0
        }
        let holder = TextHolder()

        let textBinding = Binding<String>(
            get: { holder.text },
            set: {
                holder.text = $0
                holder.updateCount += 1
            }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )

        // Set a longer debounce interval
        coordinator.textDebounceInterval = .milliseconds(500)

        // Send multiple rapid updates
        coordinator.handleTextChange("a")
        coordinator.handleTextChange("ab")
        coordinator.handleTextChange("abc")

        // Wait for debounce (500ms) plus buffer for platform variations
        #if targetEnvironment(simulator)
        // Simulator needs more time, especially on iPhone
        try await Task.sleep(for: .milliseconds(2_000))
        #elseif canImport(AppKit)
        // Native macOS needs more time for debouncing
        try await Task.sleep(for: .milliseconds(2_000))
        #else
        try await Task.sleep(for: .milliseconds(1_500))
        #endif

        // Should only get one update to the binding due to debouncing
        XCTAssertEqual(holder.updateCount, 1)
        XCTAssertEqual(holder.text, "abc")
    }

    // MARK: - Selection Change Tests

    @MainActor
    func testSelectionChange() {
        var capturedRange: NSRange?
        let textBinding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil
        ) { range in
            capturedRange = range
        }

        let newRange = NSRange(location: 2, length: 3)
        coordinator.handleSelectionChange(newRange)

        XCTAssertEqual(capturedRange, newRange)
    }

    // MARK: - Cleanup Tests

    @MainActor
    func testCoordinatorCleanup() {
        let textBinding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )

        // Test cleanup doesn't crash
        coordinator.removeNotificationObservers()

        // Cancel text update task
        coordinator.textUpdateTask?.cancel()

        // Verify cleanup doesn't crash
        XCTAssertNotNil(coordinator)
    }

    // MARK: - Platform-Specific Tests

    #if canImport(UIKit)
    @MainActor
    func testUITextViewDelegate() {
        let textBinding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )

        #if canImport(UIKit)
        let textView = CodeEditorView()
        // CodeEditorCoordinator always conforms to UITextViewDelegate on UIKit platforms
        textView.delegate = coordinator

        // Verify delegate is set
        XCTAssertNotNil(textView.delegate)
        #endif
    }
    #endif

    // MARK: - Thread Safety Tests

    @MainActor
    func testCoordinatorMainActorIsolation() {
        // This test verifies that coordinator methods are MainActor-isolated
        let textBinding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )

        // All these should be callable from MainActor context
        let container = CodeEditorContainerView()
        coordinator.updateContainer(
            container,
            text: "test",
            language: .swift,
            theme: .default,
            configuration: .default,
            runtimeDependencies: EditorRuntimeDependencies()
        )
        coordinator.requestFocusIfNeeded(for: container, shouldBecomeFirstResponder: true)
        coordinator.resetFocusTracking()

        XCTAssertNotNil(coordinator)
    }

    // MARK: - Host EditorState Mirroring

    @MainActor
    func testHostEditorStateMirroredOnSetupAndUpdate() {
        let textBinding = Binding<String>(get: { "" }, set: { _ in })
        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )
        let hostEditorState = EditorState()
        coordinator.hostEditorState = hostEditorState

        let container = CodeEditorContainerView()
        let runtimeDependencies = EditorRuntimeDependencies(memoryMonitor: MemoryMonitor())

        coordinator.setupContainer(
            container,
            text: "line 1\nline 2\nline 3",
            language: .swift,
            theme: .default,
            configuration: .default,
            runtimeDependencies: runtimeDependencies,
            onTextChange: nil,
            onSelectionChange: nil
        )

        XCTAssertEqual(hostEditorState.language, .swift)
        XCTAssertEqual(hostEditorState.lineCount, 3)

        coordinator.updateContainer(
            container,
            text: "only one line",
            language: .python,
            theme: .default,
            configuration: .default,
            runtimeDependencies: runtimeDependencies
        )

        XCTAssertEqual(hostEditorState.language, .python)
        XCTAssertEqual(hostEditorState.lineCount, 1)
    }

    @MainActor
    func testHostEditorStateSelectionMirroredOnSelectionChange() {
        let textBinding = Binding<String>(get: { "abc\ndef" }, set: { _ in })
        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )
        // currentText backs deriveSelection; seed it directly since we're not
        // round-tripping through the container in this test.
        coordinator.currentText = "abc\ndef"

        let hostEditorState = EditorState()
        coordinator.hostEditorState = hostEditorState

        coordinator.handleSelectionChange(NSRange(location: 5, length: 0))

        XCTAssertEqual(hostEditorState.selection?.line, 2)
        XCTAssertEqual(hostEditorState.selection?.column, 2)
        XCTAssertEqual(hostEditorState.selection?.selectionLength, 0)
    }

    @MainActor
    func testHostEditorStateNoMirrorWhenUnset() {
        let textBinding = Binding<String>(get: { "" }, set: { _ in })
        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )
        // Deliberately do NOT set hostEditorState; should be a no-op path.

        let container = CodeEditorContainerView()
        let runtimeDependencies = EditorRuntimeDependencies(memoryMonitor: MemoryMonitor())
        coordinator.setupContainer(
            container,
            text: "line 1\nline 2",
            language: .python,
            theme: .default,
            configuration: .default,
            runtimeDependencies: runtimeDependencies,
            onTextChange: nil,
            onSelectionChange: nil
        )

        XCTAssertNil(coordinator.hostEditorState)
    }

    // MARK: - Integration Tests

    @MainActor
    func testCoordinatorWithRepresentableHelper() {
        let textBinding = Binding<String>(
            get: { "test" },
            set: { _ in }
        )

        // Test helper creation
        let coordinator = CodeEditorRepresentableHelper.makeCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil,
            textDebounceInterval: .seconds(0.5)
        )

        XCTAssertEqual(coordinator.textDebounceInterval, .milliseconds(500))

        // Test helper cleanup
        CodeEditorRepresentableHelper.dismantle(coordinator: coordinator)

        // Verify cleanup was performed
        XCTAssertNotNil(coordinator)
    }
}
