import CodeEditorInstrumentation
import Foundation

// MARK: - Integration Extensions

extension CodeEditorView {
    /// Track performance of an operation through the editor's injected performance system.
    ///
    /// When the injected tracker is not a concrete `UnifiedPerformanceSystem`
    /// (e.g. a host-supplied `NoOpPerformanceTracker`), the operation runs
    /// untracked — matching the marker protocol's documented cast-back pattern.
    public func trackPerformance<T>(
        _ metric: PerformanceMetricType,
        operation: () async throws -> T
    ) async throws -> T {
        guard let system = runtime.dependencies.unifiedPerformanceSystem as? UnifiedPerformanceSystem else {
            return try await operation()
        }
        return try await system.track(metric, operation: operation)
    }
}
