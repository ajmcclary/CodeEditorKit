#if canImport(AppKit) && canImport(SwiftUI)
import CodeEditorCommon
import Combine
import SwiftUI

/// Hover action installed by `.onTextHover` and carried DOWN the environment,
/// so a `CodeEditor` wrapped by the modifier can deliver its bus events to it.
/// (`\.editorEventBus` only exists inside `CodeEditor`'s own body, so a
/// modifier applied outside the editor cannot subscribe to the bus itself.)
@available(macOS 13.0, iOS 16.0, *)
package struct TextHoverAction {
    package let idleDelay: Duration
    package let perform: @Sendable (SourcePosition?) async -> Void

    package init(idleDelay: Duration, perform: @escaping @Sendable (SourcePosition?) async -> Void) {
        self.idleDelay = idleDelay
        self.perform = perform
    }
}

/// Command-click action installed by `.onCommandClick`; see `TextHoverAction`.
@available(macOS 13.0, iOS 16.0, *)
package struct CommandClickAction {
    package let perform: @MainActor (SourcePosition) -> Void

    package init(perform: @escaping @MainActor (SourcePosition) -> Void) {
        self.perform = perform
    }
}

@available(macOS 13.0, iOS 16.0, *)
private struct TextHoverActionKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: TextHoverAction? = nil
}

@available(macOS 13.0, iOS 16.0, *)
private struct CommandClickActionKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: CommandClickAction? = nil
}

@available(macOS 13.0, iOS 16.0, *)
extension EnvironmentValues {
    package var textHoverAction: TextHoverAction? {
        get { self[TextHoverActionKey.self] }
        set { self[TextHoverActionKey.self] = newValue }
    }

    package var commandClickAction: CommandClickAction? {
        get { self[CommandClickActionKey.self] }
        set { self[CommandClickActionKey.self] = newValue }
    }
}

@available(macOS 13.0, iOS 16.0, *)
extension View {
    /// Delivers `bus` events to the hover and command-click actions found in
    /// the environment. `CodeEditor` applies this to itself with its
    /// controller's bus; the public modifiers apply it when a host injected
    /// `\.editorEventBus` directly.
    package func dispatchPointerActions(
        bus: EditorEventBus?,
        hover: TextHoverAction?,
        commandClick: CommandClickAction?
    ) -> some View {
        modifier(PointerActionDispatch(bus: bus, hover: hover, commandClick: commandClick))
    }
}

@available(macOS 13.0, iOS 16.0, *)
private struct PointerActionDispatch: ViewModifier {
    let bus: EditorEventBus?
    let hover: TextHoverAction?
    let commandClick: CommandClickAction?

    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onReceive(hoverPublisher) { position in
                hoverTask?.cancel()
                guard let hover else { return }
                let delay = hover.idleDelay
                let perform = hover.perform
                hoverTask = Task { @MainActor in
                    if delay > .zero {
                        try? await Task.sleep(for: delay)
                    }
                    guard !Task.isCancelled else { return }
                    await perform(position)
                }
            }
            .onReceive(commandClickPublisher) { position in
                guard let commandClick else { return }
                // `onReceive` delivers on the main runloop.
                MainActor.assumeIsolated {
                    commandClick.perform(position)
                }
            }
    }

    private var hoverPublisher: AnyPublisher<SourcePosition?, Never> {
        guard hover != nil, let bus else { return Empty().eraseToAnyPublisher() }
        return bus.hoverPublisher
    }

    private var commandClickPublisher: AnyPublisher<SourcePosition, Never> {
        guard commandClick != nil, let bus else { return Empty().eraseToAnyPublisher() }
        return bus.commandClickPublisher
    }
}
#endif
