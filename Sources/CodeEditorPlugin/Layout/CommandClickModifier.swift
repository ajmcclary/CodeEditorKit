#if canImport(AppKit) && canImport(SwiftUI)
import Combine
import SwiftUI

@available(macOS 13.0, iOS 16.0, *)
extension View {
    /// Call `action` when the user clicks the editor's text while holding the
    /// Command key. The click is consumed — the caret does not reposition.
    public func onCommandClick(
        action: @escaping (SourcePosition) -> Void
    ) -> some View {
        modifier(CommandClickModifier(action: action))
    }
}

@available(macOS 13.0, iOS 16.0, *)
private struct CommandClickModifier: ViewModifier {
    let action: (SourcePosition) -> Void

    @Environment(\.editorEventBus) private var bus

    func body(content: Content) -> some View {
        content.onReceive(busPublisher) { position in
            action(position)
        }
    }

    private var busPublisher: AnyPublisher<SourcePosition, Never> {
        bus?.commandClickPublisher ?? Empty().eraseToAnyPublisher()
    }
}
#endif
