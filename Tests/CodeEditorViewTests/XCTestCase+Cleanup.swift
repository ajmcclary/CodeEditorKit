import CodeEditorConfiguration
import CodeEditorPlatform
@testable import CodeEditorView
import XCTest

/// Extension to provide better cleanup support for tests
extension XCTestCase {
    /// Registry of cleanup handlers
    nonisolated(unsafe) private static var cleanupHandlers: [ObjectIdentifier: [() -> Void]] = [:]
    private static let cleanupLock = NSLock()

    /// Register a cleanup handler to be called in tearDown
    func addCleanupHandler(_ handler: @escaping () -> Void) {
        Self.cleanupLock.lock()
        defer { Self.cleanupLock.unlock() }

        let key = ObjectIdentifier(self)
        if Self.cleanupHandlers[key] == nil {
            Self.cleanupHandlers[key] = []
        }
        Self.cleanupHandlers[key]?.append(handler)
    }

    /// Execute all registered cleanup handlers
    func executeCleanupHandlers() {
        Self.cleanupLock.lock()
        let handlers = Self.cleanupHandlers[ObjectIdentifier(self)] ?? []
        Self.cleanupHandlers[ObjectIdentifier(self)] = nil
        Self.cleanupLock.unlock()

        // Execute handlers in reverse order (LIFO)
        for handler in handlers.reversed() {
            handler()
        }
    }

    /// Create a resource with automatic cleanup
    func createWithCleanup<T>(
        create: () throws -> T,
        cleanup: @escaping (T) -> Void
    ) rethrows -> T {
        let resource = try create()
        addCleanupHandler { cleanup(resource) }
        return resource
    }

    /// Create a resource with async cleanup
    func createWithAsyncCleanup<T: Sendable>(
        create: () async throws -> T,
        cleanup: @escaping @Sendable (T) async -> Void
    ) async rethrows -> T {
        let resource = try await create()
        addCleanupHandler {
            Task.detached {
                await cleanup(resource)
            }
        }
        return resource
    }
}

/// Sendable wrapper for views
private struct ViewWrapper: @unchecked Sendable {
    let view: PlatformView
}

/// Sendable wrapper for timers
private struct TimerWrapper: @unchecked Sendable {
    let timer: Timer
}

/// Sendable wrapper for notification tokens
private struct TokenWrapper: @unchecked Sendable {
    let token: NSObjectProtocol
}

/// Base test class with automatic cleanup
open class CleanupTestCase: XCTestCase {
    /// Thread-safe storage for resources that need cleanup
    private let resourceLock = NSLock()
    private var viewsToClean: [ViewWrapper] = []
    private var timersToClean: [TimerWrapper] = []
    private var tokensToClean: [TokenWrapper] = []

    override open func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override open func tearDown() {
        // Get resources to clean in a thread-safe way
        resourceLock.lock()
        let views = viewsToClean
        let timers = timersToClean
        let tokens = tokensToClean
        viewsToClean.removeAll()
        timersToClean.removeAll()
        tokensToClean.removeAll()
        resourceLock.unlock()

        // Clean up resources
        if !views.isEmpty || !timers.isEmpty || !tokens.isEmpty {
            // Use a semaphore to wait for MainActor cleanup
            let semaphore = DispatchSemaphore(value: 0)

            Task { @MainActor in
                // Clean up views
                for wrapper in views {
                    let view = wrapper.view
                    if let editorView = view as? CodeEditorView {
                        editorView.text = ""
                        editorView.language = .plainText
                        editorView.textDelegate = nil
                    }
                    view.removeFromSuperview()
                }

                // Clean up timers
                for wrapper in timers {
                    wrapper.timer.invalidate()
                }

                // Clean up notifications
                for wrapper in tokens {
                    NotificationCenter.default.removeObserver(wrapper.token)
                }

                semaphore.signal()
            }

            // Wait for cleanup to complete
            _ = semaphore.wait(timeout: .now() + 1.0)
        }

        // Execute any registered cleanup handlers
        executeCleanupHandlers()

        // Force autorelease cleanup
        autoreleasepool {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        super.tearDown()
    }

    /// Add a view for cleanup
    private func registerViewForCleanup(_ view: PlatformView) {
        resourceLock.lock()
        viewsToClean.append(ViewWrapper(view: view))
        resourceLock.unlock()
    }

    /// Add a timer for cleanup
    private func registerTimerForCleanup(_ timer: Timer) {
        resourceLock.lock()
        timersToClean.append(TimerWrapper(timer: timer))
        resourceLock.unlock()
    }

    /// Add a notification token for cleanup
    private func registerNotificationTokenForCleanup(_ token: NSObjectProtocol) {
        resourceLock.lock()
        tokensToClean.append(TokenWrapper(token: token))
        resourceLock.unlock()
    }

    /// Create a CodeEditorView with automatic cleanup
    @MainActor
    func createCodeEditorView(
        frame: CGRect = .zero,
        configuration: EditorConfiguration? = nil
    ) -> CodeEditorView {
        let editor = CodeEditorView(frame: frame)
        if let configuration {
            editor.configuration = configuration
        }
        registerViewForCleanup(editor)
        return editor
    }

    /// Create a timer with automatic cleanup
    @MainActor
    func createTimer(
        timeInterval: TimeInterval,
        repeats: Bool = false,
        block: @escaping @Sendable (Timer) -> Void
    ) -> Timer {
        let timer = Timer.scheduledTimer(
            withTimeInterval: timeInterval,
            repeats: repeats,
            block: block
        )
        registerTimerForCleanup(timer)
        return timer
    }

    /// Observe a notification with automatic cleanup
    @MainActor
    func observeNotification(
        _ name: Notification.Name,
        object: Any? = nil,
        queue: OperationQueue? = nil,
        using block: @escaping @Sendable (Notification) -> Void
    ) {
        let token = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: queue,
            using: block
        )
        registerNotificationTokenForCleanup(token)
    }
}

/// Cleanup utilities for specific test scenarios
enum TestCleanupUtilities {
    /// Clean up all cached syntax highlighters
    static func cleanupSyntaxHighlighters() {
        // Clear any cached highlighters
        // Clear any cached highlighters - implementation specific to cache system
    }

    /// Clean up all LSP connections
    @MainActor
    static func cleanupLSPConnections() async {
        // This would disconnect all active LSP connections
        // Implementation depends on LSP manager structure
    }

    /// Reset all singletons to default state
    @MainActor
    static func resetSingletons() {
        // Reset any singleton state that might affect tests
        TestMemoryOptimizer.shared.reset()
    }

    /// Force garbage collection (best effort)
    static func forceCleanup() {
        // Multiple autorelease pool drains
        for _ in 0..<3 {
            autoreleasepool {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            }
        }
    }
}

/// Protocol for test classes that need custom cleanup
protocol TestCleanupProtocol: AnyObject {
    /// Perform custom cleanup operations
    func performCustomCleanup() async
}

/// Extension to automatically call custom cleanup
extension XCTestCase {
    func performCustomCleanupIfNeeded() async {
        if let cleanupProtocol = self as? TestCleanupProtocol {
            await cleanupProtocol.performCustomCleanup()
        }
    }
}
