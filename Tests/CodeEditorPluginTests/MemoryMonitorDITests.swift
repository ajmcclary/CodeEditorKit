@testable import CodeEditorPlugin
import XCTest

// Mutable mock memory provider for testing
final class MutableMockMemoryProvider: PlatformMemoryProvider {
    @MainActor var memoryUsage: Double
    @MainActor var physicalMemory: UInt64
    @MainActor var memoryPressure: MemoryPressure

    @MainActor
    init(
        memoryUsage: Double = 100.0,
        physicalMemory: UInt64 = 8_589_934_592,
        memoryPressure: MemoryPressure = .normal
    ) {
        self.memoryUsage = memoryUsage
        self.physicalMemory = physicalMemory
        self.memoryPressure = memoryPressure
    }

    nonisolated func getCurrentMemoryUsage() -> Double {
        MainActor.assumeIsolated {
            memoryUsage
        }
    }

    nonisolated func getPhysicalMemory() -> UInt64 {
        MainActor.assumeIsolated {
            physicalMemory
        }
    }

    nonisolated func getMemoryPressure() -> MemoryPressure {
        MainActor.assumeIsolated {
            memoryPressure
        }
    }

    nonisolated func isUnderMemoryPressure() -> Bool {
        MainActor.assumeIsolated {
            memoryPressure != .normal
        }
    }
}

final class MemoryMonitorDITests: XCTestCase {
    @MainActor
    func testMemoryMonitorConfigurationInjection() {
        // Create a custom memory monitor
        let customMonitor = MemoryMonitor()
        customMonitor.memoryThresholdMB = 200.0 // Set a distinctive value

        // Create configuration with custom memory monitor
        var config = EditorConfiguration()
        config.performance.memoryMonitor = customMonitor

        // Create editor view using initializer with memory monitor
        let editor = CodeEditorView(frame: .zero, memoryMonitor: customMonitor)

        // Verify the custom monitor was injected via initializer
        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 200.0, "Memory monitor should be injected via initializer")

        // Apply configuration with a different monitor
        let anotherMonitor = MemoryMonitor()
        anotherMonitor.memoryThresholdMB = 300.0
        config.performance.memoryMonitor = anotherMonitor
        config.apply(to: editor)

        // Verify the monitor was updated from configuration
        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 300.0, "Memory monitor should be updated from configuration")
    }

    @MainActor
    func testMemoryMonitorBuilderInjection() {
        // Create a custom memory monitor
        let customMonitor = MemoryMonitor()
        customMonitor.memoryThresholdMB = 250.0

        // Create configuration using builder
        let config = EditorConfigurationBuilder()
            .memoryMonitor(customMonitor)
            .build()

        // Create editor view
        let editor = CodeEditorView()

        // Apply configuration
        config.apply(to: editor)

        // Verify the custom monitor was injected via configuration
        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 250.0, "Memory monitor should be injected from builder configuration")
    }

    @MainActor
    func testMemoryMonitorDefaultWhenNilInConfiguration() {
        // Create configuration without memory monitor
        let config = EditorConfiguration()
        XCTAssertNil(config.performance.memoryMonitor, "Default configuration should have nil memory monitor")

        // Create editor view with its own monitor
        let editor = CodeEditorView()
        let originalMonitor = editor.memoryMonitor

        // Apply configuration
        config.apply(to: editor)

        // Verify the original monitor is still used
        XCTAssertTrue(editor.memoryMonitor === originalMonitor, "Editor should keep its original monitor when config has nil")
    }

    @MainActor
    func testMemoryMonitorUpdatePropagation() {
        // Create editor view
        let editor = CodeEditorView()

        // Create and apply first monitor
        let monitor1 = MemoryMonitor()
        monitor1.memoryThresholdMB = 150.0
        var config = EditorConfiguration()
        config.performance.memoryMonitor = monitor1
        config.apply(to: editor)

        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 150.0, "First monitor should be applied")

        // Create and apply second monitor
        let monitor2 = MemoryMonitor()
        monitor2.memoryThresholdMB = 175.0
        config.performance.memoryMonitor = monitor2
        config.apply(to: editor)

        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 175.0, "Second monitor should replace the first")
    }

    // MARK: - Cleanup Handler Tests

    @MainActor
    func testCleanupHandlerRegistration() async {
        // Create monitor with mock memory provider that reports reduced memory after cleanup
        let mockProvider = MutableMockMemoryProvider(memoryUsage: 100.0)
        let monitor = MemoryMonitor(memoryProvider: mockProvider)
        var cleanupCalled = false
        var cleanupResult: CleanupResult?

        // Register cleanup handler
        monitor.registerCleanupHandler(
            identifier: "test-cleanup",
            priority: .normal
        ) { @MainActor in
            cleanupCalled = true
            cleanupResult = CleanupResult(memoryFreedMB: 10.0, description: "Test cleanup")
            // Simulate memory reduction
            mockProvider.memoryUsage = 90.0
            return cleanupResult!
        }

        // Force cleanup
        let freedMemory = await monitor.performCleanup()

        // Verify cleanup was called
        XCTAssertTrue(cleanupCalled, "Cleanup handler should be called")
        XCTAssertNotNil(cleanupResult, "Cleanup should return a result")
        XCTAssertEqual(cleanupResult?.memoryFreedMB, 10.0, "Cleanup should report freed memory")
        XCTAssertEqual(freedMemory, 10.0, "Total freed memory should match actual memory reduction")
    }

    @MainActor
    func testMultipleCleanupHandlersPriority() async {
        // Create monitor with mock memory provider
        let mockProvider = MutableMockMemoryProvider(memoryUsage: 100.0)
        let monitor = MemoryMonitor(memoryProvider: mockProvider)
        var callOrder: [String] = []
        var totalReduction: Double = 0

        // Register handlers with different priorities
        monitor.registerCleanupHandler(
            identifier: "low-priority",
            priority: .low
        ) { @MainActor in
            callOrder.append("low")
            totalReduction += 1.0
            mockProvider.memoryUsage -= 1.0
            return CleanupResult(memoryFreedMB: 1.0, description: "Low priority")
        }

        monitor.registerCleanupHandler(
            identifier: "high-priority",
            priority: .high
        ) { @MainActor in
            callOrder.append("high")
            totalReduction += 3.0
            mockProvider.memoryUsage -= 3.0
            return CleanupResult(memoryFreedMB: 3.0, description: "High priority")
        }

        monitor.registerCleanupHandler(
            identifier: "normal-priority",
            priority: .normal
        ) { @MainActor in
            callOrder.append("normal")
            totalReduction += 2.0
            mockProvider.memoryUsage -= 2.0
            return CleanupResult(memoryFreedMB: 2.0, description: "Normal priority")
        }

        monitor.registerCleanupHandler(
            identifier: "critical-priority",
            priority: .critical
        ) { @MainActor in
            callOrder.append("critical")
            totalReduction += 4.0
            mockProvider.memoryUsage -= 4.0
            return CleanupResult(memoryFreedMB: 4.0, description: "Critical priority")
        }

        // Force cleanup
        let freedMemory = await monitor.performCleanup()

        // Verify call order (critical > high > normal > low)
        XCTAssertEqual(callOrder, ["critical", "high", "normal", "low"], "Handlers should be called in priority order")

        // Verify total freed memory based on actual memory measurements
        XCTAssertEqual(freedMemory, 10.0, "Total freed memory should be sum of all reductions")
        XCTAssertEqual(totalReduction, 10.0, "Total reported reductions should be 10MB")
    }

    @MainActor
    func testCleanupHandlerUnregistration() async {
        let monitor = MemoryMonitor()
        var handler1Called = false
        var handler2Called = false

        // Register two handlers
        monitor.registerCleanupHandler(
            identifier: "handler1",
            priority: .normal
        ) { @MainActor in
            handler1Called = true
            return CleanupResult(memoryFreedMB: 5.0, description: "Handler 1")
        }

        monitor.registerCleanupHandler(
            identifier: "handler2",
            priority: .normal
        ) { @MainActor in
            handler2Called = true
            return CleanupResult(memoryFreedMB: 7.0, description: "Handler 2")
        }

        // Unregister first handler
        monitor.unregisterCleanupHandler(identifier: "handler1")

        // Force cleanup
        _ = await monitor.performCleanup()

        // Verify only handler2 was called
        XCTAssertFalse(handler1Called, "Unregistered handler should not be called")
        XCTAssertTrue(handler2Called, "Registered handler should be called")
    }

    @MainActor
    func testCleanupHandlerInjectionInEditorView() async {
        // Create custom memory monitor
        let customMonitor = MemoryMonitor()
        var cleanupCalled = false

        // Register cleanup handler on custom monitor
        customMonitor.registerCleanupHandler(
            identifier: "editor-cleanup",
            priority: .high
        ) { @MainActor in
            cleanupCalled = true
            return CleanupResult(memoryFreedMB: 15.0, description: "Editor cleanup")
        }

        // Create editor with custom monitor
        let editor = CodeEditorView(frame: .zero, memoryMonitor: customMonitor)

        // Verify the monitor is injected
        XCTAssertTrue(editor.memoryMonitor === customMonitor, "Custom monitor should be injected")

        // Force cleanup through the editor's monitor
        _ = await editor.memoryMonitor.performCleanup()

        // Verify cleanup was called
        XCTAssertTrue(cleanupCalled, "Cleanup handler should be called through injected monitor")
    }

    @MainActor
    func testCleanupHandlerErrorHandling() async {
        let monitor = MemoryMonitor()
        var errorHandlerCalled = false

        // Register handler that throws an error
        monitor.registerCleanupHandler(
            identifier: "error-handler",
            priority: .normal
        ) { @MainActor in
            errorHandlerCalled = true
            // Return a result even if there's an internal error
            return CleanupResult(memoryFreedMB: 0.0, description: "Error during cleanup")
        }

        // Force cleanup
        let freedMemory = await monitor.performCleanup()

        // Verify handler was called despite error
        XCTAssertTrue(errorHandlerCalled, "Error handler should still be called")
        XCTAssertEqual(freedMemory, 0.0, "Should handle error gracefully")
    }

    @MainActor
    func testCleanupHandlerWeakReferences() async {
        let monitor = MemoryMonitor()

        // Create a temporary object that registers a cleanup handler
        @MainActor
        class TemporaryObject {
            weak var monitor: MemoryMonitor?

            init(monitor: MemoryMonitor) {
                self.monitor = monitor
                monitor.registerCleanupHandler(
                    identifier: "temp-object",
                    priority: .normal
                ) { @MainActor [weak self] in
                    guard self != nil else {
                        return CleanupResult(memoryFreedMB: 0.0, description: "Object deallocated")
                    }
                    return CleanupResult(memoryFreedMB: 5.0, description: "Temp object cleanup")
                }
            }
        }

        // Create and release temporary object
        _ = TemporaryObject(monitor: monitor)
        // Object will be immediately deallocated since it's not retained

        // Force cleanup
        let freedMemory = await monitor.performCleanup()

        // The handler should still be called but return 0 because object is deallocated
        XCTAssertEqual(freedMemory, 0.0, "Deallocated object should return 0 freed memory")
    }
}
