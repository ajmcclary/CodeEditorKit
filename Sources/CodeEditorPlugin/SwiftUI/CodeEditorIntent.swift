//
//  CodeEditorIntent.swift
//  CodeEditorPlugin
//
//  Carries the closures and reference bindings supplied by the
//  `CodeEditor` modifier chain that previously lived as stored
//  properties on the `CodeEditor` struct. Internal: modifiers are
//  public; the env value carrying their state is implementation
//  detail.
//
//  Spec: docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md
//

#if canImport(SwiftUI)
import CodeEditorCompletion
import SwiftUI

@available(macOS 13.0, iOS 16.0, *)
struct CodeEditorIntent: Sendable {
    // `@MainActor` so consumers don't have to wrap the body in
    // `MainActor.assumeIsolated { ... }` to touch their main-isolated host
    // state (sample `AppState`, observable models, etc.).
    var onTextChange: (@MainActor @Sendable (String) -> Void)?
    var onSelectionChange: (@Sendable (Range<String.Index>?) -> Void)?
    var completionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
    var editorController: EditorController?
    var interactionState: Binding<EditorInteractionState>?
}

@available(macOS 13.0, iOS 16.0, *)
private struct CodeEditorIntentKey: EnvironmentKey {
    static let defaultValue = CodeEditorIntent()
}

@available(macOS 13.0, iOS 16.0, *)
extension EnvironmentValues {
    /// Editor intent populated by `CodeEditor` modifier chain. Read by
    /// `CodeEditor.body` and forwarded into the representable/coordinator.
    var codeEditorIntent: CodeEditorIntent {
        get { self[CodeEditorIntentKey.self] }
        set { self[CodeEditorIntentKey.self] = newValue }
    }
}

#endif
