import CodeEditorDiagnostics
import Foundation

// MARK: - Integration Extensions

extension CodeEditorView {
    /// Track performance of an operation through the editor's injected performance system.
    public func trackPerformance<T>(
        _ metric: PerformanceMetricType,
        operation: () async throws -> T
    ) async throws -> T {
        try await runtime.dependencies.unifiedPerformanceSystem.track(metric, operation: operation)
    }
}
