/// The lightweight runtime instrumentation (memory monitor, performance
/// counters, LRU cache, adaptive performance mode, hardware-acceleration
/// helpers) moved to the lean `CodeEditorInstrumentation` target so that
/// editor targets can consume it without the full diagnostics system
/// (insights, dashboards, frame-rate monitoring).
///
/// Re-exported here so existing `import CodeEditorDiagnostics` consumers keep
/// seeing `MemoryMonitor`, `UnifiedPerformanceSystem`, `LRUCache`, and friends
/// without a source change.
@_exported import CodeEditorInstrumentation
