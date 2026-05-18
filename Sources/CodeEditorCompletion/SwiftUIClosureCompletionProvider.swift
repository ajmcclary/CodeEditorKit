#if canImport(SwiftUI)
import CodeEditorLanguages
import Foundation

/// Adapter that wraps the closure attached via the `.codeCompletion(provider:)`
/// SwiftUI modifier as a `CompletionProvider`, so the closure can join
/// the rest of the per-editor provider registry without the modifier
/// API needing to know about `CompletionProvider`'s richer surface.
///
/// Owned by `CodeEditorBaseCoordinator`. The coordinator swaps the
/// `closure` slot on every representable update (idempotent — no
/// register/unregister churn) and unregisters the adapter only when
/// the host removes the modifier.
///
/// - id: constant `"swiftui-modifier"` — at most one adapter per editor;
///   re-renders are dictionary-key replacements that leave the manager
///   undisturbed.
/// - supportedLanguages: `[]` — applies to every language; the host
///   inspects `ctx.language` inside the closure and early-returns for
///   unsupported langs. (`CompletionManager` interprets an empty array
///   as "matches any language" via the existing filter.)
/// - triggerCharacters: `[]` — manual trigger only. Hosts wanting
///   trigger-driven firing register a full `CompletionProvider` via
///   `EditorController.registerCompletionProvider(_:)`.
@MainActor
package final class SwiftUIClosureCompletionProvider: CompletionProvider {
    package let id: String = "swiftui-modifier"
    package let supportedLanguages: [Language] = []
    package let triggerCharacters: [String] = []
    package let supportsSnippets: Bool = true

    /// Mutable slot the coordinator swaps on every representable update.
    /// `nil` indicates "no modifier attached this update" — `completions`
    /// returns an empty result rather than throwing or crashing.
    package var closure: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?

    package init() {}

    package func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        guard let closure else {
            return CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0
            )
        }

        let bridged = SwiftUICompletionContext(
            text: context.text,
            cursorPosition: context.cursorPosition,
            language: context.language
        )

        let start = Date()
        let swiftUIItems = await closure(bridged)
        let elapsed = Date().timeIntervalSince(start)

        let modelItems = swiftUIItems.map { CompletionItemModel(swiftUI: $0) }

        return CompletionResult(
            items: modelItems,
            context: context,
            isIncomplete: false,
            processingTime: elapsed
        )
    }
}

// MARK: - SwiftUICompletionItem → CompletionItemModel

extension CompletionItemModel {
    /// Translates a `SwiftUICompletionItem` (the modifier API's surface
    /// type) into the framework's richer `CompletionItemModel`. Lives
    /// here so the conversion table sits next to the adapter that uses
    /// it.
    ///
    /// Priority comes from the kind's `defaultPriority` — the SwiftUI
    /// modifier API has no `priority` field, and defaulting to `0` would
    /// bury host items behind built-in keywords (priority 80) past the
    /// `maxCompletions: Int = 50` cap. Hosts who need custom priority
    /// register a full `CompletionProvider` via `EditorController`.
    init(swiftUI item: SwiftUICompletionItem) {
        let mappedKind = CompletionItemKind(swiftUI: item.kind)
        self.init(
            label: item.label,
            insertText: item.insertText,
            kind: mappedKind,
            detail: item.detail,
            documentation: item.documentation,
            priority: mappedKind.defaultPriority
        )
    }
}

extension CompletionItemKind {
    init(swiftUI kind: CompletionKind) {
        switch kind {
        case .keyword:   self = .keyword
        case .function:  self = .function
        case .method:    self = .method
        case .variable:  self = .variable
        case .constant:  self = .constant
        case .class:     self = .class
        case .struct:    self = .struct
        case .enum:      self = .enum
        case .interface: self = .interface
        case .module:    self = .module
        case .property:  self = .property
        case .value:     self = .value
        case .reference: self = .reference
        case .snippet:   self = .snippet
        case .text:      self = .text
        }
    }
}
#endif
