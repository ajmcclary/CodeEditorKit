#if canImport(AppKit) && canImport(SwiftUI)
import CodeEditorCommon
import Combine
import SwiftUI

@available(macOS 13.0, iOS 16.0, *)
extension View {
    /// Call `action` when the user clicks the editor's text while holding the
    /// Command key. The click is consumed — the caret does not reposition.
    /// The action is `@MainActor`-isolated, matching `onReceive`'s
    /// main-runloop delivery, so consumers can touch main-isolated state
    /// without wrapping the body in `Task { @MainActor in ... }`.
    public func onCommandClick(
        action: @escaping @MainActor (SourcePosition) -> Void
    ) -> some View {
        modifier(CommandClickModifier(action: action))
    }
}

@available(macOS 13.0, iOS 16.0, *)
private struct CommandClickModifier: ViewModifier {
    let action: @MainActor (SourcePosition) -> Void

    @Environment(\.editorEventBus) private var bus

    func body(content: Content) -> some View {
        let click = CommandClickAction(perform: action)
        // See `TextHoverModifier`: the environment carries the action into a
        // wrapped `CodeEditor`; an injected bus is served directly.
        content
            .environment(\.commandClickAction, click)
            .dispatchPointerActions(bus: bus, hover: nil, commandClick: click)
    }
}
#endif
