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
        content.onReceive(busPublisher) { position in
            // `onReceive` delivers on the main runloop. The closure runs
            // synchronously on the main thread, so calling a @MainActor
            // function here is well-defined.
            MainActor.assumeIsolated {
                action(position)
            }
        }
    }

    private var busPublisher: AnyPublisher<SourcePosition, Never> {
        bus?.commandClickPublisher ?? Empty().eraseToAnyPublisher()
    }
}
#endif
