#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI environment key carrying a live `EditorState`.
///
/// Hosts that integrate `CodeEditorUI` chrome should instantiate an
/// `EditorState`, hold it in `@State`, and inject it via
/// `.environment(\.editorState, state)`. Hosts without chrome can ignore
/// this key — the editor writes through the shared sentinel default
/// returned below and observation no-ops because no view is reading.
@MainActor
public struct EditorStateEnvironmentKey: @preconcurrency EnvironmentKey {
    /// Shared sentinel returned when no host injects a real `EditorState`.
    ///
    /// Previously a computed property that allocated a fresh `EditorState`
    /// on every read — once the framework began writing through the env
    /// (language/selection/lineCount mirror, 2026-05-14), each `body` call
    /// that read `\.editorState` paid for an `EditorState()` allocation.
    /// The sentinel collapses every unattached editor onto a single
    /// instance: writes from those editors all land on `shared`, but no
    /// chrome view reads it (hosts that wire chrome inject their own),
    /// so the writes are inert. Hosts that share chrome across multiple
    /// editors must still inject an explicit `EditorState` per editor
    /// instance.
    public static let defaultValue = EditorState()

    public typealias Value = EditorState
}

extension EnvironmentValues {
    /// The shared `EditorState` for chrome and editor integration.
    ///
    /// Defaults to a process-wide sentinel `EditorState` (see
    /// ``EditorStateEnvironmentKey/defaultValue``); replace by injecting
    /// an explicit instance with `.environment(\.editorState, _:)`.
    public var editorState: EditorState {
        get { self[EditorStateEnvironmentKey.self] }
        set { self[EditorStateEnvironmentKey.self] = newValue }
    }
}
#endif
