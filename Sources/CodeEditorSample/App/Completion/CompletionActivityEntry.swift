#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// One completion fire as observed by `TelemetryCompletionProvider`.
/// Used by `CompletionSampleCoordinator` for its recent-activity ring
/// and `CompletionInspectorPanel` for the "Last request" row.
struct CompletionActivityEntry: Sendable, Identifiable {
    let id = UUID()
    let providerId: String
    let language: Language
    let triggerCharacter: String?
    let prefix: String          // truncated to ≤ 32 chars
    let itemCount: Int
    let durationMs: Double
    let timestamp: Date
    let error: String?          // nil on success
}
#endif
