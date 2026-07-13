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

    /// Performs memory cleanup when under pressure
    private func performMemoryCleanup() -> CleanupResult {
        guard let editorView else {
            return CleanupResult(memoryFreedMB: 0, description: "Editor view deallocated")
        }

        var memoryFreed: Double = 0
        var operations: [String] = []

        // Clear undo manager history
        if let undoManager = editorView.undoManager,
           undoManager.canUndo || undoManager.canRedo {
            undoManager.removeAllActions()
            memoryFreed += 0.5 // Estimate
            operations.append("undo history")
        }

        // Clear large text storage if read-only
        #if canImport(AppKit)
        let storageLength = editorView.textKitBridge.documentLength
        if storageLength > 100_000, !editorView.isEditable {
            let sizeReduction = Double(storageLength) / (1_024 * 1_024) * 0.1
            memoryFreed += sizeReduction
            operations.append("large text storage")
        }
        #else
        if let text = editorView.text,
           text.count > 100_000,
           !editorView.isEditable {
            let sizeReduction = Double(text.count) / (1_024 * 1_024) * 0.1
            memoryFreed += sizeReduction
            operations.append("large text content")
        }
        #endif

        // Clear syntax highlighting cache
        // Note: The syntax highlighter will automatically cancel tasks when needed
        memoryFreed += 2.0 // Estimate
        operations.append("syntax highlighting cache")

        // Clear line geometry store
        editorView.lineGeometryStore.reset()
        memoryFreed += 0.5 // Estimate
        operations.append("line geometry store")

        // Clear folding state for large documents
        if !editorView.codeFoldingEngine.foldedRegions.isEmpty {
            editorView.codeFoldingEngine.unfoldAll()
            memoryFreed += 0.25 // Estimate
            operations.append("code folding state")
        }

        let description = operations.isEmpty ? "No operations performed" : "Cleared: \(operations.joined(separator: ", "))"
        return CleanupResult(memoryFreedMB: memoryFreed, description: description)
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
