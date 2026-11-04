#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
@testable import CodeEditorLayout
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import SwiftUI
import XCTest

/// API-shape tests for the hover and command-click modifiers. The end-to-end
/// "modifier applied outside `CodeEditor` fires when the bus emits" path is
/// `CodeEditorPointerActionTests`.
final class HoverAndClickModifierTests: XCTestCase {
    @MainActor
    func testOnTextHoverModifierCompilesAndAccepts() {
        // Smoke-test: the modifier accepts the documented signature and
        // produces a View. We're confirming the public API surface, not the
        // runtime subscription (covered by the integration test).
        let view = Color.clear.onTextHover { _ in /* action */ }
        _ = view
    }

    @MainActor
    func testOnCommandClickModifierCompilesAndAccepts() {
        let view = Color.clear.onCommandClick { _ in /* action */ }
        _ = view
    }

    @MainActor
    func testOnTextHoverAcceptsCustomIdleDelay() {
        let view = Color.clear.onTextHover(idleDelay: .milliseconds(100)) { _ in }
        _ = view
    }

    @MainActor
    func testEditorEventBusEnvironmentKeyExists() {
        // Environment injection point exists and accepts the bus type.
        let bus = EditorEventBus()
        let view = Color.clear.environment(\.editorEventBus, bus)
        _ = view
    }
}
#endif
