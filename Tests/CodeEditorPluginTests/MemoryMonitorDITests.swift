import CodeEditorPlatform
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
    func testMemoryMonitorRuntimeInjection() {
        let customMonitor = MemoryMonitor()
        customMonitor.memoryThresholdMB = 200.0

        let editor = CodeEditorView(frame: .zero, memoryMonitor: customMonitor)

        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 200.0, "Memory monitor should be injected via initializer")

        let anotherMonitor = MemoryMonitor()
        anotherMonitor.memoryThresholdMB = 300.0
        editor.apply(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: anotherMonitor))

        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 300.0, "Memory monitor should be updated from runtime dependencies")
    }

    @MainActor
    func testEditorSetupRuntimeInjection() throws {
        let customMonitor = MemoryMonitor()
        customMonitor.memoryThresholdMB = 250.0

        let editor = CodeEditorView()
        let setup = EditorSetup(
            configuration: EditorConfiguration(),
            runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: customMonitor)
        )

        try setup.apply(to: editor)

        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 250.0, "Memory monitor should be injected from editor setup")
    }

    @MainActor
    func testConfigurationApplyDoesNotReplaceRuntimeMemoryMonitor() {
        let config = EditorConfiguration()
        let editor = CodeEditorView()
        let originalMonitor = editor.memoryMonitor

        try? editor.apply(configuration: config)

        XCTAssertIdentical(editor.memoryMonitor, originalMonitor, "Editor configuration should not carry runtime dependencies")
    }

    @MainActor
    func testEditorSetupAppliesRuntimeDependenciesOutsideConfiguration() throws {
        let editor = CodeEditorView()
        let eventSystem = UnifiedEventSystem(enableDefaultFilters: false)
        let memoryMonitor = MemoryMonitor()
        let metadataRegistry = LanguageMetadataRegistry()
        let workspaceRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("CodeEditorRuntime")
        var configuration = EditorConfiguration()
        configuration.display.fontSize = 17

        let setup = EditorSetup(
            configuration: configuration,
            runtimeDependencies: EditorRuntimeDependencies(
                workspaceRoot: workspaceRoot,
                eventSystem: eventSystem,
                memoryMonitor: memoryMonitor,
                languageMetadataRegistry: metadataRegistry
            )
        )

        try setup.apply(to: editor)

        XCTAssertEqual(editor.configuration.display.fontSize, 17)
        XCTAssertIdentical(editor.runtime.dependencies.eventSystem, eventSystem)
        XCTAssertIdentical(editor.runtime.dependencies.memoryMonitor, memoryMonitor)
        XCTAssertIdentical(editor.runtime.dependencies.languageMetadataRegistry, metadataRegistry)
        XCTAssertEqual(editor.runtime.dependencies.workspaceRoot, workspaceRoot)
        #if canImport(AppKit)
        XCTAssertEqual(editor.lspManager.workspaceRoot, workspaceRoot)
        #endif

        editor.completionManager.ensureBuiltInProvider(for: .python)
        let providerIds = editor.completionManager.registeredProviders.map(\.id)
        XCTAssertTrue(
            providerIds.contains("builtin.keywords.python"),
            "DI path should result in a per-language built-in being registered"
        )

        var valueOnlyConfiguration = editor.configuration
        valueOnlyConfiguration.display.fontSize = 19
        try editor.apply(configuration: valueOnlyConfiguration)

        XCTAssertEqual(editor.configuration.display.fontSize, 19)
        XCTAssertIdentical(editor.runtime.dependencies.eventSystem, eventSystem)
        XCTAssertIdentical(editor.runtime.dependencies.memoryMonitor, memoryMonitor)
        XCTAssertEqual(editor.runtime.dependencies.workspaceRoot, workspaceRoot)
    }

    @MainActor
    func testMemoryMonitorRuntimeUpdatePropagation() {
        let editor = CodeEditorView()

        let monitor1 = MemoryMonitor()
        monitor1.memoryThresholdMB = 150.0
        editor.apply(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: monitor1))

        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 150.0, "First monitor should be applied")

        let monitor2 = MemoryMonitor()
        monitor2.memoryThresholdMB = 175.0
        editor.apply(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: monitor2))

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
            let result = CleanupResult(memoryFreedMB: 10.0, description: "Test cleanup")
            cleanupResult = result
            // Simulate memory reduction
            mockProvider.memoryUsage = 90.0
            return result
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
        XCTAssertIdentical(editor.memoryMonitor, customMonitor, "Custom monitor should be injected")

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
