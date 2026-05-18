#if canImport(SwiftUI)
import CodeEditorCommon
import Combine
import SwiftUI

/// Internal seam between the wrapped editor view (AppKit on macOS) and the
/// SwiftUI hover/command-click modifiers. Held inside the SwiftUI environment
/// so any descendant of the editor can subscribe without leaking AppKit types.
///
/// The bus is created by `CodeEditor` (or, in tests, directly) and shared
/// downstream via the `\.editorEventBus` environment key.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
package final class EditorEventBus {
    private let hoverSubject = PassthroughSubject<SourcePosition?, Never>()
    private let commandClickSubject = PassthroughSubject<SourcePosition, Never>()

    package init() {}

    package var hoverPublisher: AnyPublisher<SourcePosition?, Never> {
        hoverSubject.eraseToAnyPublisher()
    }

    package var commandClickPublisher: AnyPublisher<SourcePosition, Never> {
        commandClickSubject.eraseToAnyPublisher()
    }

    package func emitHover(at position: SourcePosition?) {
        hoverSubject.send(position)
    }

    package func emitCommandClick(at position: SourcePosition) {
        commandClickSubject.send(position)
    }
}

// MARK: - SwiftUI environment

@available(macOS 13.0, iOS 16.0, *)
private struct EditorEventBusKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: EditorEventBus? = nil
}

@available(macOS 13.0, iOS 16.0, *)
extension EnvironmentValues {
    package var editorEventBus: EditorEventBus? {
        get { self[EditorEventBusKey.self] }
        set { self[EditorEventBusKey.self] = newValue }
    }
}
#endif
