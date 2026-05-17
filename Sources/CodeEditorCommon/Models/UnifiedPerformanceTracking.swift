import Foundation

/// Type-erased handle for `UnifiedPerformanceSystem` (defined in the umbrella target).
///
/// Exists so that `EditorConfiguration.Performance.unifiedPerformanceSystem` can hold a
/// reference to a `UnifiedPerformanceSystem` without `CodeEditorConfiguration` depending
/// on the umbrella target where that class lives. Call sites that want to invoke
/// `UnifiedPerformanceSystem` methods cast back via `as? UnifiedPerformanceSystem`.
public protocol UnifiedPerformanceTracking: AnyObject, Sendable {}
