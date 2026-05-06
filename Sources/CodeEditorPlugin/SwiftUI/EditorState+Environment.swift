#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI environment key carrying a live `EditorState`.
///
/// Hosts that integrate `CodeEditorUI` chrome should instantiate an
/// `EditorState`, hold it in `@State`, and inject it via
/// `.environment(\.editorState, state)`. Hosts without chrome can ignore
/// this key — the editor writes to the env's default (a fresh empty
/// instance per access) and observation no-ops because no view is reading.
@MainActor
public struct EditorStateEnvironmentKey: @preconcurrency EnvironmentKey {
    public static var defaultValue: EditorState { EditorState() }

    public typealias Value = EditorState
}

extension EnvironmentValues {
    /// The shared `EditorState` for chrome and editor integration.
    ///
    /// Defaults to a fresh empty `EditorState` per access; replace by
    /// injecting an explicit instance with `.environment(\.editorState, _:)`.
    public var editorState: EditorState {
        get { self[EditorStateEnvironmentKey.self] }
        set { self[EditorStateEnvironmentKey.self] = newValue }
    }
}
#endif
