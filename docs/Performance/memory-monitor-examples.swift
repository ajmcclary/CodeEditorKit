import CodeEditorPlugin
import SwiftUI

// MARK: - Example 1: Basic Memory Monitor Setup

func basicMemoryMonitorSetup() {
    // Create and configure a memory monitor
    let memoryMonitor = MemoryMonitor()

    // Configure thresholds
    memoryMonitor.memoryThresholdMB = 150.0  // Cleanup at 150MB
    memoryMonitor.enableAutomaticCleanup = true
    memoryMonitor.enablePeriodicCleanup = true
    memoryMonitor.periodicCleanupInterval = 300.0  // Every 5 minutes

    // Create editor with custom monitor
    let editor = CodeEditorView()
    var config = EditorConfiguration()
    config.performance.memoryMonitor = memoryMonitor
    config.apply(to: editor)
}

// MARK: - Example 2: Injected Memory Monitor Pattern

class EditorManager {
    private let editorMemoryMonitor = MemoryMonitor()
    private let imageCache = ImageCache()
    private let syntaxCache = SyntaxCache()

    init() {
        configureMemoryMonitor()
    }

    private func configureMemoryMonitor() {
        editorMemoryMonitor.memoryThresholdMB = 300.0
        editorMemoryMonitor.enableAutomaticCleanup = true

        // Register app-wide cleanup handlers
        editorMemoryMonitor.registerCleanupHandler(
            identifier: "image-cache",
            priority: .high
        ) { @MainActor in
            // Clear image cache
            let freed = imageCache.clear()
            return CleanupResult(memoryFreedMB: freed, description: "Cleared image cache")
        }

        editorMemoryMonitor.registerCleanupHandler(
            identifier: "syntax-cache",
            priority: .normal
        ) { @MainActor in
            // Clear syntax highlighting cache
            let freed = syntaxCache.clear()
            return CleanupResult(memoryFreedMB: freed, description: "Cleared syntax cache")
        }
    }

    func createEditor() -> CodeEditorView {
        let editor = CodeEditorView()

        var config = EditorConfiguration()
        config.performance.memoryMonitor = editorMemoryMonitor
        config.apply(to: editor)

        return editor
    }
}

// MARK: - Example 3: SwiftUI App with Memory Management

struct CodeEditorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

@MainActor
class AppState: ObservableObject {
    let memoryMonitor = MemoryMonitor()

    init() {
        setupMemoryMonitor()
    }

    private func setupMemoryMonitor() {
        // Configure for desktop app
        memoryMonitor.memoryThresholdMB = 500.0
        memoryMonitor.monitoringInterval = 30.0

        // Register cleanup for app-specific resources
        memoryMonitor.registerCleanupHandler(
            identifier: "document-cache",
            priority: .normal
        ) { @MainActor in
            // Clear old document caches
            CleanupResult(memoryFreedMB: 25.0, description: "Cleared document cache")
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var documents: [Document] = []

    var body: some View {
        NavigationView {
            DocumentList(documents: $documents)

            if let activeDoc = documents.first(where: { $0.isActive }) {
                DocumentEditor(document: activeDoc, memoryMonitor: appState.memoryMonitor)
            }
        }
    }
}

struct DocumentEditor: View {
    let document: Document
    let memoryMonitor: MemoryMonitor
    private var configuration: EditorConfiguration {
        var config = EditorConfiguration()
        config.performance.memoryMonitor = memoryMonitor
        config.display.isLineNumbersEnabled = true
        return config
    }

    var body: some View {
        CodeEditor(text: .constant(document.content))
            .codeLanguage(document.language)
            .environment(
                \.codeEditorConfiguration,
                configuration
            )
    }
}

// MARK: - Example 4: Custom Memory Monitor for Testing

class TestableMemoryMonitor: MemoryMonitor {
    var cleanupCalls: [(identifier: String, freed: Double)] = []
    var mockMemoryUsage: Double = 50.0

    override func getCurrentMemoryUsage() -> Double {
        mockMemoryUsage
    }

    override func performCleanup(targetReduction: Double? = nil) async -> Double {
        cleanupCalls.append((identifier: "manual", freed: targetReduction ?? 0))
        return targetReduction ?? 20.0
    }
}

@MainActor
class EditorTests: XCTestCase {
    func testMemoryCleanupIntegration() async {
        // Create testable monitor
        let testMonitor = TestableMemoryMonitor()
        testMonitor.mockMemoryUsage = 200.0

        // Configure editor
        let editor = CodeEditorView()
        var config = EditorConfiguration()
        config.performance.memoryMonitor = testMonitor
        config.apply(to: editor)

        // Simulate high memory usage
        testMonitor.mockMemoryUsage = 350.0

        // Trigger cleanup
        let freed = await testMonitor.performCleanup(targetReduction: 100.0)

        XCTAssertEqual(freed, 100.0)
        XCTAssertEqual(testMonitor.cleanupCalls.count, 1)
    }
}

// MARK: - Example 5: Platform-Specific Memory Configuration

func configurePlatformSpecificMemory() -> MemoryMonitor {
    let monitor = MemoryMonitor()

    #if canImport(UIKit)
    // iOS: more aggressive memory management on the mobile heap
    monitor.memoryThresholdMB = 100.0
    monitor.monitoringInterval = 10.0
    monitor.enableAutomaticCleanup = true

    // Register iOS-specific handlers
    monitor.registerCleanupHandler(identifier: "image-thumbnails", priority: .high) { @MainActor in
        // Clear thumbnail cache on iOS
        CleanupResult(memoryFreedMB: 15.0, description: "Cleared thumbnails")
    }

    #elseif canImport(AppKit)
    // macOS: More relaxed thresholds
    monitor.memoryThresholdMB = 500.0
    monitor.monitoringInterval = 60.0
    monitor.enablePeriodicCleanup = true
    monitor.periodicCleanupInterval = 600.0  // 10 minutes

    // Register macOS-specific handlers
    monitor.registerCleanupHandler(identifier: "preview-cache", priority: .normal) { @MainActor in
        // Clear preview cache on macOS
        CleanupResult(memoryFreedMB: 50.0, description: "Cleared preview cache")
    }
    #endif

    return monitor
}

// MARK: - Example 6: Memory Monitoring Dashboard

struct MemoryDashboard: View {
    @ObservedObject var monitor: MemoryMonitor
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Memory Usage")
                    .font(.headline)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }

            if isExpanded {
                MemoryStatsView(stats: monitor.memoryStats)

                HStack {
                    Button("Force Cleanup") {
                        Task {
                            await monitor.performCleanup()
                        }
                    }

                    Button("Reset Stats") {
                        monitor.resetStatistics()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MemoryStatsView: View {
    let stats: MemoryStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StatRow(label: "Current", value: "\(Int(stats.currentUsageMB)) MB")
            StatRow(label: "Peak", value: "\(Int(stats.peakUsageMB)) MB")
            StatRow(label: "Average", value: "\(Int(stats.averageUsageMB)) MB")
            StatRow(label: "Cleanups", value: "\(stats.totalCleanupOperations)")
            StatRow(label: "Total Freed", value: "\(Int(stats.totalMemoryFreed)) MB")

            if stats.totalCleanupOperations > 0 {
                StatRow(
                    label: "Effectiveness",
                    value: "\(Int(stats.cleanupEffectiveness)) MB/cleanup"
                )
            }
        }
        .font(.system(.caption, design: .monospaced))
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

// MARK: - Example 7: Multi-Window Memory Management

#if canImport(AppKit)
class WindowManager: ObservableObject {
    static let shared = WindowManager()

    private let globalMemoryMonitor = MemoryMonitor()
    private var windowMonitors: [NSWindow: MemoryMonitor] = [:]

    init() {
        setupGlobalMonitor()
    }

    private func setupGlobalMonitor() {
        globalMemoryMonitor.memoryThresholdMB = 1_000.0  // 1GB global threshold

        globalMemoryMonitor.registerCleanupHandler(
            identifier: "close-inactive-windows",
            priority: .critical
        ) { @MainActor in
            // Close inactive windows to free memory
            var freed = 0.0
            for (window, monitor) in self.windowMonitors {
                if !window.isKeyWindow && !window.isMainWindow {
                    freed += monitor.getCurrentMemoryUsage()
                    window.close()
                }
            }
            return CleanupResult(memoryFreedMB: freed, description: "Closed inactive windows")
        }
    }

    func createWindowMonitor(for window: NSWindow) -> MemoryMonitor {
        // Each window gets its own monitor, but they coordinate through the global one
        let windowMonitor = MemoryMonitor()
        windowMonitor.memoryThresholdMB = 200.0  // Per-window threshold

        // Register with global monitor
        globalMemoryMonitor.registerCleanupHandler(
            identifier: "window-\(window.windowNumber)",
            priority: .normal
        ) { @MainActor in
            // Delegate to window's monitor
            await windowMonitor.performCleanup()
        }

        windowMonitors[window] = windowMonitor
        return windowMonitor
    }

    func removeWindowMonitor(for window: NSWindow) {
        if windowMonitors.removeValue(forKey: window) != nil {
            globalMemoryMonitor.unregisterCleanupHandler(
                identifier: "window-\(window.windowNumber)"
            )
        }
    }
}
#endif

// MARK: - Supporting Types for Examples

struct Document {
    let id: UUID
    let content: String
    let language: Language
    let isActive: Bool
}

class ImageCache {
    func clear() -> Double { 30.0 }
}

class SyntaxCache {
    func clear() -> Double { 15.0 }
}
