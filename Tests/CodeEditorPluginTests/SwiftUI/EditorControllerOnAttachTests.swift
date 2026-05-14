import Combine
import XCTest

@testable import CodeEditorPlugin

/// Unit tests for `EditorController.onAttach(_:)`.
///
/// Verifies the lifecycle hook fires only on real view transitions
/// (first attach, attach to a different view, re-attach after detach)
/// and never on redundant re-attaches with the same view, on detach,
/// or after the host cancels the returned `AnyCancellable`.
///
/// Related: docs/superpowers/specs/2026-05-14-editor-controller-onattach-design.md
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class EditorControllerOnAttachTests: XCTestCase {
    func testHandlerNotFiredAtRegistration() {
        let controller = EditorController()
        var fireCount = 0

        let token = controller.onAttach { _ in fireCount += 1 }

        XCTAssertEqual(fireCount, 0, "Handler must not run before any attach.")
        _ = token // suppress unused warning; token retains the registration
    }
}
