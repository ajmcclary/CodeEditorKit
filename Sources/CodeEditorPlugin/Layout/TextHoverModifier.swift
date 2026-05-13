#if canImport(AppKit) && canImport(SwiftUI)
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
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.onReceive(busPublisher) { position in
            task?.cancel()
            let delay = idleDelay
            let captured = action
            task = Task { @MainActor in
                if delay > .zero {
                    try? await Task.sleep(for: delay)
                }
                guard !Task.isCancelled else { return }
                await captured(position)
            }
        }
    }

    private var busPublisher: AnyPublisher<SourcePosition?, Never> {
        bus?.hoverPublisher ?? Empty().eraseToAnyPublisher()
    }
}
#endif
