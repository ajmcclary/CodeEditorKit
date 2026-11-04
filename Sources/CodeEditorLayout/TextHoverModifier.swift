#if canImport(AppKit) && canImport(SwiftUI)
import CodeEditorCommon
import Combine
import SwiftUI

@available(macOS 13.0, iOS 16.0, *)
extension View {
    /// Call `action` after the pointer has been still over the editor's text
    /// for `idleDelay`. The action receives the resolved `SourcePosition`, or
    /// `nil` if the pointer has left the text region (for example, moved over
    /// the gutter or chrome). Previous calls are cancelled when the pointer
    /// moves before completion. Pointer-only on macOS.
    public func onTextHover(
        idleDelay: Duration = .milliseconds(500),
        action: @escaping @Sendable (SourcePosition?) async -> Void
    ) -> some View {
        modifier(TextHoverModifier(idleDelay: idleDelay, action: action))
    }
}

@available(macOS 13.0, iOS 16.0, *)
private struct TextHoverModifier: ViewModifier {
    let idleDelay: Duration
    let action: @Sendable (SourcePosition?) async -> Void

    @Environment(\.editorEventBus) private var bus

    func body(content: Content) -> some View {
        let hover = TextHoverAction(idleDelay: idleDelay, perform: action)
        // A wrapped `CodeEditor` reads the action from the environment and
        // dispatches its controller's bus events to it. A host that injected
        // `\.editorEventBus` above this modifier is served directly.
        content
            .environment(\.textHoverAction, hover)
            .dispatchPointerActions(bus: bus, hover: hover, commandClick: nil)
    }
}
#endif
