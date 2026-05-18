import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorView
import XCTest

/// Comprehensive tests for Swift 6 concurrency compliance and actor isolation
@MainActor
final class ConcurrencyTests: XCTestCase {
    // MARK: - Basic Actor Isolation Tests

    func testMainActorIsolationBoundaries() async throws {
        let editorView = CodeEditorView()
        editorView.text = "func test() {}"

        // Verify that UI updates only happen on MainActor
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                // This should work - we're on MainActor
                editorView.language = .swift
                XCTAssertEqual(editorView.language, .swift)
            }

            group.addTask { @MainActor in
                // Test configuration updates
                var config = EditorConfiguration.default
                config.display.fontSize = 16.0
                editorView.configuration = config
                XCTAssertEqual(editorView.configuration.display.fontSize, 16.0)
            }
        }
    }

    // MARK: - Memory Management Tests

    func testMemoryMonitorActorSafety() async throws {
        let monitor = MemoryMonitor()

        // Test concurrent registration/unregistration
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<10 {
                group.addTask { @MainActor in
                    let identifier = "test-handler-\(index)"
                    monitor.registerCleanupHandler(
                        identifier: identifier,
                        priority: .normal
                    ) { @MainActor in
                        CleanupResult(memoryFreedMB: 1.0, description: "Test cleanup \(index)")
                    }

                    // Immediately unregister to test concurrent access
                    monitor.unregisterCleanupHandler(identifier: identifier)
                }
            }
        }
    }

    // MARK: - Configuration Thread Safety Tests

    func testConfigurationConcurrentUpdates() async throws {
        let editorView = CodeEditorView()

        await withTaskGroup(of: Void.self) { group in
            // Test concurrent configuration updates
            for index in 0..<10 {
                group.addTask { @MainActor in
                    var config = EditorConfiguration.default
                    config.display.fontSize = CGFloat(12 + index)
                    config.layout.tabWidth = 2 + index
                    editorView.configuration = config
                }
            }
        }

        // Verify final state is consistent
        let finalConfig = editorView.configuration
        XCTAssertGreaterThanOrEqual(finalConfig.display.fontSize, 12.0)
        XCTAssertGreaterThanOrEqual(finalConfig.layout.tabWidth, 2)
    }

    // MARK: - Task Cancellation Tests

    func testTaskCancellationHandling() async throws {
        // Create a task that we'll cancel
        let task = Task { @MainActor in
            let editorView = CodeEditorView()
            let longText = String(repeating: "func test() { print(\"very long text\") }\n", count: 100)
            editorView.text = longText
            return editorView.text?.count ?? 0
        }

        // Cancel immediately
        task.cancel()

        // The task should handle cancellation gracefully or complete normally
        let result = await task.value
        XCTAssertGreaterThanOrEqual(result, 0)
    }

    // MARK: - Concurrent Editor Creation

    func testConcurrentEditorViewCreation() async throws {
        await withTaskGroup(of: String?.self) { group in
            for index in 0..<5 {
                group.addTask { @MainActor in
                    let editorView = CodeEditorView()
                    editorView.text = "func test\(index)() {}"
                    editorView.language = .swift
                    return editorView.text
                }
            }

            var texts: [String] = []
            for await text in group {
                if let text {
                    texts.append(text)
                }
            }

            XCTAssertEqual(texts.count, 5)
            for text in texts {
                XCTAssertTrue(text.contains("test"))
            }
        }
    }

    // MARK: - Error Handling in Concurrent Context

    func testConcurrentErrorHandling() async throws {
        await withTaskGroup(of: Void.self) { group in
            // Test error handling with invalid configurations
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    var config = EditorConfiguration.default
                    // Intentionally set invalid values to test error handling
                    config.display.fontSize = -1.0  // Invalid
                    config.layout.tabWidth = -1     // Invalid

                    // The configuration system should handle this gracefully
                    let errors = config.validate()
                    XCTAssertFalse(errors.isEmpty, "Should detect validation errors")
                }
            }
        }
    }

    // MARK: - Sendable Compliance Tests

    func testSendableTypeCompliance() async throws {
        // Test that our key types can be safely passed across actor boundaries
        let config = EditorConfiguration.default
        let language = Language.swift

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // These should compile without warnings since they're Sendable
                _ = config
                _ = language
            }
        }
    }

    // MARK: - Performance Under Concurrency

    func testConcurrentPerformance() async throws {
        let startTime = Date()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask { @MainActor in
                    let editorView = CodeEditorView()
                    editorView.text = "func test\(index)() {\n    print(\"Testing concurrent performance \(index)\")\n}"
                    editorView.language = .swift
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Should complete within reasonable time. Enforce the stopwatch threshold only in
        // pinned performance jobs because parallel package tests can add scheduler noise.
        assertMeasuredDuration(duration, lessThan: 5.0, operation: "concurrent editor creation")
    }

    // MARK: - Multiple Editor Views Concurrency

    func testMultipleEditorViewsConcurrency() async throws {
        let editorViews = (0..<5).map { _ in CodeEditorView() }

        await withTaskGroup(of: Void.self) { group in
            for (index, editorView) in editorViews.enumerated() {
                group.addTask { @MainActor in
                    editorView.text = "func editor\(index)Test() {}"
                    editorView.language = .swift

                    var config = EditorConfiguration.default
                    config.display.fontSize = CGFloat(14 + index)
                    editorView.configuration = config
                }
            }
        }

        // Verify all editors were configured correctly
        for (index, editorView) in editorViews.enumerated() {
            XCTAssertTrue(editorView.text?.contains("editor\(index)Test") ?? false)
            XCTAssertEqual(editorView.configuration.display.fontSize, CGFloat(14 + index))
        }
    }
}

// MARK: - Test Utilities

extension ConcurrencyTests {
    /// Helper to create a test editor view with initial setup
    @MainActor
    private func createTestEditorView() -> CodeEditorView {
        let view = CodeEditorView()
        view.language = .swift
        view.text = "func testFunction() {}"
        return view
    }

    /// Helper to generate test code of specific length
    private func generateTestCode(length: Int) -> String {
        let baseCode = "func test() { print(\"hello\") }\n"
        let repetitions = max(1, length / baseCode.count)
        return String(repeating: baseCode, count: repetitions)
    }
}
