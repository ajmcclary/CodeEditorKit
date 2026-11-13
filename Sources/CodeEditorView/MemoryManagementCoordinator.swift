import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorInstrumentation
import CodeEditorPlatform
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Coordinates memory management across all subsystems of a CodeEditorView
///
/// This coordinator centralizes memory management logic, handling:
/// - Component initialization with proper memory monitoring
/// - Memory pressure response coordination
/// - Resource cleanup on view deallocation
/// - Dynamic memory monitor updates
@MainActor
public final class MemoryManagementCoordinator {
    // MARK: - Properties

    /// The memory monitor instance
    private(set) var memoryMonitor: any MemoryMonitoring

    /// Weak reference to the editor view
    private weak var editorView: CodeEditorView?

    /// Policy controlling cleanup registration side effects.
    private var policy: MemoryManagementPolicy

    /// Managed components that use memory monitoring
    private struct ManagedComponents {
        var asyncHighlighter: AsyncSyntaxHighlighter?
        var completionManager: CompletionManager?
    }

    private var components = ManagedComponents()

    /// Cleanup handler identifier
    private var cleanupIdentifier: String?

    // MARK: - Initialization

    // swiftlint:disable function_default_parameter_at_end
    /// Creates a new memory management coordinator
    /// - Parameters:
    ///   - memoryMonitor: The memory monitor to use
    ///   - editorView: The editor view to manage
    public init(
        memoryMonitor: any MemoryMonitoring,
        policy: MemoryManagementPolicy = .live,
        editorView: CodeEditorView
    ) {
        self.memoryMonitor = memoryMonitor
        self.policy = policy
        self.editorView = editorView
        setupMemoryMonitoring()
    }
    // swiftlint:enable function_default_parameter_at_end

    package var hasRegisteredCleanupHandler: Bool {
        cleanupIdentifier != nil
    }

    deinit {
        // The cleanup handler captures `[weak self]`, so it survives this
        // deinit and the monitor never reclaims its dictionary slot on its
        // own. Unregister explicitly so closing many editors doesn't
        // accumulate dead handlers that fire on every periodic cleanup pass.
        guard let identifier = cleanupIdentifier else { return }
        let monitor = memoryMonitor
        Task { @MainActor in
            monitor.unregisterCleanupHandler(identifier: identifier)
        }
    }

    // MARK: - Component Creation

    /// Creates and returns an AsyncSyntaxHighlighter with proper memory monitoring
    public func createAsyncHighlighter() -> AsyncSyntaxHighlighter {
        let highlighter = AsyncSyntaxHighlighter(memoryMonitor: memoryMonitor)
        components.asyncHighlighter = highlighter
        return highlighter
    }

    /// Creates and returns a CompletionManager with proper memory monitoring
    public func createCompletionManager() -> CompletionManager {
        let manager = CompletionManager(memoryMonitor: memoryMonitor)
        components.completionManager = manager
        return manager
    }

    // MARK: - Memory Monitor Updates

    /// Updates the memory monitor and all managed components
    /// - Parameter newMonitor: The new memory monitor to use
    public func updateMemoryMonitor(_ newMonitor: any MemoryMonitoring) {
        guard newMonitor !== memoryMonitor else { return }

        // Unregister from old monitor
        if let identifier = cleanupIdentifier {
            memoryMonitor.unregisterCleanupHandler(identifier: identifier)
            cleanupIdentifier = nil
        }

        // Update monitor
        memoryMonitor = newMonitor

        // Re-register with new monitor
        setupMemoryMonitoring()

        // Update all components
        updateComponentsMemoryMonitor()
    }

    /// Updates cleanup registration without consulting ambient process state.
    public func updatePolicy(_ newPolicy: MemoryManagementPolicy) {
        guard newPolicy != policy else { return }

        policy = newPolicy
        if newPolicy.registersCleanupHandlers {
            setupMemoryMonitoring()
        } else if let identifier = cleanupIdentifier {
            memoryMonitor.unregisterCleanupHandler(identifier: identifier)
            cleanupIdentifier = nil
        }
    }

    // MARK: - Private Methods

    /// Sets up memory monitoring and cleanup handlers
    private func setupMemoryMonitoring() {
        guard policy.registersCleanupHandlers, cleanupIdentifier == nil else { return }

        // Generate unique identifier
        var hasher = Hasher()
        if let editorView {
            hasher.combine(ObjectIdentifier(editorView))
        }
        let identifier = "MemoryManagementCoordinator_\(hasher.finalize())"
        cleanupIdentifier = identifier

        // Register cleanup handler
        memoryMonitor.registerCleanupHandler(
            identifier: identifier,
            priority: .normal
        ) { [weak self] in
            self?.performMemoryCleanup() ?? CleanupResult(memoryFreedMB: 0, description: "Coordinator deallocated")
        }
    }

    /// Updates memory monitor for all managed components
    private func updateComponentsMemoryMonitor() {
        components.asyncHighlighter?.setMemoryMonitor(memoryMonitor)
        components.completionManager?.setMemoryMonitor(memoryMonitor)
    }

    /// The editor's part of a cleanup pass.
    ///
    /// A pass is routine: the monitor runs one whenever the process
    /// footprint is over its threshold (a host app always is) and on a
    /// timer. So it must leave everything the user can see or get back
    /// alone. The undo history is the user's (it used to be discarded on
    /// every pass, the window's whole stack before each editor had its own),
    /// as are the text, the selection and the folds; the line geometry store
    /// is the editor's line index, not a cache (emptying it made every gutter
    /// line number read "1"). The caches a pass is for (highlighting tokens
    /// and completion responses) are released by their owners' own handlers
    /// on the same monitor, and are rebuilt on demand.
    internal func performMemoryCleanup() -> CleanupResult {
        guard editorView != nil else {
            return CleanupResult(memoryFreedMB: 0, description: "Editor view deallocated")
        }
        return CleanupResult(memoryFreedMB: 0, description: "No operations performed")
    }
}

// MARK: - Integration Extension

extension CodeEditorView {
    /// Sets up memory management coordination
    internal func setupMemoryManagement() {
        memoryCoordinator.updateMemoryMonitor(memoryMonitor)
        self.asyncHighlighter = memoryCoordinator.createAsyncHighlighter()
        self.completionManager = memoryCoordinator.createCompletionManager()
    }
}
